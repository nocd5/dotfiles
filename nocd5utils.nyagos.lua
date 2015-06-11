------------------------------------------------
local UpdatePromptAlways = 1
--
-- ディレクトリ移動時にPROMPTを変更する
-- makePrompt()が重い(特にネットワークドライブ上など)ので
-- ディレクトリ移動時にのみPROMPTを更新
local PROMPT = ''
__cd = function(arg)
    r, err = nyagos.exec('__cd__ "' .. arg .. '"')
    PROMPT = makePrompt()
    return r, err
end
local _prompt = nyagos.prompt
nyagos.prompt = function(template)
    nyagos.setenv('VDATE', os.date('%y%m%d_%H%M%S'))
    nyagos.setenv('DATE', os.date('%y%m%d'))
    if (UpdatePromptAlways == 1) then
        return _prompt(makePrompt())
    else
        if (PROMPT == '') then
            PROMPT = makePrompt()
        end
        return _prompt(PROMPT)
    end
end

------------------------------------------------
-- PROMPT生成部分
function makePrompt()
    local prompt  = '$e[30;40;1m[' .. getCompressedPath(3):gsub('\\', '/') .. ']$e[37;1m'
    local hgbranch = nyagos.eval('hg branch 2> nul')
    local gitbranch = ''
    gitbranch_tmp = nyagos.eval('git branch 2> nul')
    if (gitbranch_tmp ~= '') then
        gitbranch = gitbranch_tmp:match('%*%s(.[^\n]+)', 1)
    end
    rprompt = ''
    if (hgbranch ~= '') then
        rprompt = rprompt .. '$e[30;40;1m[$e[33;40;1m' .. hgbranch .. '$e[30;40;1m]$e[37;1m'
    end
    if (gitbranch ~= '') then
        rprompt = rprompt .. '$e[30;40;1m[$e[33;40;1m' .. gitbranch .. '$e[30;40;1m]$e[37;1m'
    end
    pad = nyagos.getviewwidth() - getStringWidth(removeEscapeSequence(prompt .. rprompt))
    for i = 1, pad-1 do
        prompt = prompt .. ' '
    end
    return prompt .. rprompt .. '\n$ '
end
------------------------------------------------

------------------------------------------------
-- 文字列の幅を取得
-- 半角文字:1, 全角文字:2 にカウント
function getStringWidth(src)
    width = 0
    for p, c in utf8.codes(src) do
        if (0 ~= bit32.band(c, 0x7FFFFF80)) then
            if (0xFF61 <= c and c <= 0xFF9F) then
                width = width + 1
            else
                width = width + 2
            end
        else
            width = width + 1
        end
    end
    return width
end
function removeEscapeSequence(src)
    -- FIXME : なぜか'$e%[(%d+;)+1m'でマッチしない
    return src:gsub('$e%[%d+;%d+;1m',''):gsub('$e%[%d+;1m','')
end

------------------------------------------------
-- 最下層nのディレクトリ名だけ表示する文字列生成
function getCompressedPath(num)
    local path = chomp(nyagos.eval('pwd'))
    local buff = path

    local drive = nil

    -- HOME以下の場合
    local home = getHome()
    if path:find(home)then
        drive = '~'
        path = path:gsub(home, '~')
        buff = path
    end
    -- 通常のドライブ
    if drive == nil then
        drive = buff:match('(%w+:)\\')
        buff = buff:gsub('%w+:\\', '')
    end
    -- UNCパス
    if drive == nil then
        drive = buff:match('(\\\\.-)\\')
        buff = buff:gsub('\\\\.-\\', '')
    end

    local tbl = split(buff, "[\\/]")
    if #tbl > num then
        buff = "/..."
        for i = #tbl - (num - 1), #tbl do
            buff = buff .. '/' .. tbl[i]
        end
            path = drive .. buff
    end

    return path
end
------------------------------------------------

------------------------------------------------
-- pushd/popd/dirsの実装
------------------------------------------------
local directory_stack = {}
------------------------------------------------
-- pushd
function nocd5_pushd(args)
    local old = chomp(nyagos.eval('pwd'))
    if #args >= 1 then
        r, err = __cd('"' .. args[1] .. '"')
    else
        r, err = __cd(getHome())
    end
    if err == nil then
        table.insert(directory_stack, 1, old)
    else
        return r, err
    end
end
------------------------------------------------
-- popd
function nocd5_popd(args)
    if #directory_stack ~= 0 then
        local num = 0
        if #args == 0 then
            num = 1
        else
            num = tonumber(args[1])
        end
        __cd('"' .. directory_stack[num] .. '"')
        table.remove(directory_stack, num)
    else
        print ('popd: directories stack is empty.')
    end
end
------------------------------------------------
-- dirs
function nocd5_dirs()
    max_len = string.len(tostring(#directory_stack))
    for i, e in ipairs(directory_stack) do
        len = string.len(tostring(i))
        print(string.rep(' ', max_len - len) .. '\027[32;;1m' .. i .. '\027[;;0m : ' .. e)
    end
end
------------------------------------------------

------------------------------------------------
-- インタラクティブなディレクトリ移動
function nocd5_icd(args)
    local target = nil
    if #args == 0 then
        target = {}
    else
        local parent, pattern = args[1]:match('(.*[\\/])(.*)')
        parent = parent or ''
        pattern = pattern or args[1]
        -- '..' とドライブ名だけは別扱いで移動
        if pattern == '..' or pattern:find('^[%u%l]:$') then
            target = {parent .. pattern}
        elseif pattern == '' then
            target = {parent}
        else
            local directories = getDirectoryList(parent, pattern)
            if #directories == 0 then
                print(pattern .. ': No such directory')
            elseif #directories == 1 then
                target = {directories[1]}
            else
                max_len = string.len(tostring(#directories))
                for i, e in ipairs(directories) do
                    len = string.len(tostring(i))
                    print(string.rep(' ', max_len - len) .. '\027[32;;1m' .. i .. '\027[;;0m : ' .. e)
                end

                local index = getIndex()
                if #directories < index then
                    print(index .. ': Invalid index')
                elseif 0 < index then
                    target = {directories[index]}
                end
            end
        end
    end
    if target ~= nil then
        nocd5_pushd(target)
    end
end
------------------------------------------------
-- 条件に一致する名前を返す
-- function getMatchingDirectory(name, pattern)
--     return name:lower():match('^' .. pattern:lower() .. '.*/$')
-- end
------------------------------------------------
-- ディレクトリのリストを取得
function getDirectoryList(parent, pattern)
    if parent:find('^[\\/].*') then
        if not(parent:find('^[\\/][\\/]+')) then
            parent = nyagos.eval('pwd'):gsub('[\\/].*', '') .. parent:gsub('\\', '/')
        end
    end
    local line = nyagos.eval('ls -lar ' .. parent) -- nyagos組み込みの`ls`
    local complst = split(line, '[\r\n]')
    local directories = {}
    for i, e in ipairs(complst) do
        local name = tostring(e:gsub(".-%s+", "", 4))
        -- 末尾が'/'ならディレクトリって事で決め打ち
        if getMatchingDirectory(name, pattern) then
            -- ls -lの結果が
            -- <パーミション> <サイズ> <日付> <時間> <ファイル名 or ディレクトリ名>
            -- と出力されるので、スペースで区切られた5つ目の要素を取得
            table.insert(directories, 1, parent .. name)
        end
    end
    if parent ~= '' and #directories ~= 1 then
        table.insert(directories, 1, tostring(parent:gsub('\\', '/')))
    end
    return directories
end

------------------------------------------------
-- pecoを使ったディレクトリ移動
function nocd5_pcd(args)
    local parent
    local pattern
    if #args == 0 then
        parent = ''
        pattern = '.'
    else
        parent, pattern = args[1]:match('(.*[\\/])(.*)')
        parent = parent or ''
        pattern = pattern or args[1]
    end
    local directories = getDirectoryList(parent, pattern)
    if #directories == 0 then
        print(pattern .. ': No such directory')
    else
        local dir = nyagos.eval("echo " .. table.concat(directories, '\n') ..  " | peco")
        if dir ~= nil then
            nocd5_pushd({'"' .. chomp(dir) .. '"'})
        end
    end
end
------------------------------------------------

----------------------------------------------------------
-- gookmark Front End
function nocd5_pgm(args)
    local target = nyagos.eval('gookmark list | peco')
    if target ~= nil and target ~= "" then
        if is_dir(target) then
            nocd5_pushd({'"' .. target .. '"'})
        else
            nyagos.exec('open ' .. target)
        end
    end
end
alias { pgm=nocd5_pgm }
function nocd5_pga(args)
    local target = nyagos.eval('gookmark list --group app | peco')
    if target ~= nil and target ~= "" then
        if is_dir(target) then
            nocd5_pushd({'"' .. target .. '"'})
        else
            nyagos.exec('open ' .. target)
        end
    end
end
alias { pga=nocd5_pga }
function nocd5_pgf(args)
    local target = nyagos.eval('gookmark list --group file | peco')
    if target ~= nil and target ~= "" then
        if is_dir(target) then
            nocd5_pushd({'"' .. target .. '"'})
        else
            nyagos.exec('open ' .. target)
        end
    end
end
alias { pgf=nocd5_pgf }
function nocd5_dot(args)
    local target = nyagos.eval('gookmark list --group dot | peco')
    if target ~= nil and target ~= "" then
        if is_dir(target) then
            nocd5_pushd({'"' .. target .. '"'})
        else
            nyagos.exec('vim ' .. target)
        end
    end
end
alias { dot=nocd5_dot }
-- 
function is_dir(f)
    return nyagos.eval('file ' .. f):find(': directory')
end
----------------------------------------------------------

------------------------------------------------
-- strをpatで分割しテーブルを返す
-- code from 'http://lua-users.org/wiki/SplitJoin'
function split(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t, cap)
        end
        last_end = e+1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end
------------------------------------------------
-- srcの末尾から改行を取り除く
function chomp(src)
    return string.gsub(src, "[\r\n]+$", "")
end
------------------------------------------------
-- キーボード入力から数字を取得
GETINDEX_NO_INPUT = -1
GETINDEX_ABORT    = -2
function getIndex()
    io.write('> ')
    local index = GETINDEX_NO_INPUT -- 戻り値
    local charcnt = 0
    local stridx = io.read()

    if stridx ~= nil and (stridx ~= '') then
        index = tonumber(chomp(stridx):match('^%d+$')) or GETINDEX_NO_INPUT
    end
    return index
end
------------------------------------------------

---------------------------------------------------------
-- luamigemo関係
migemo_dict = 'C:/Tools/bin/dict/utf-8/migemo-dict'
-- 毎回migemo辞書を開くのはアレなのでグローバル変数にする
g_luamigemo = nil
function getLuamigemo()
    if g_luamigemo == nil then
        g_luamigemo = require('luamigemo')
        g_luamigemo.open(migemo_dict, "UTF-8")
    end
    return g_luamigemo
end
-- 条件に一致する名前を返す
function getMatchingDirectory(name, pattern)
    local result = false
    if name:match('.*/$') then
        local luamigemo = getLuamigemo()
        -- 正規表現に渡すパターンの下準備
        local strcf = ''
        local strque = ''
        strcf = pattern:sub(0):match('%u') and '' or 'i' -- 最初の文字が小文字ならignorecase
        result = luamigemo.migematch(pattern, name, strcf) == 0
    end
    return result
end
---------------------------------------------------------

---------------------------------------------------------
-- ${HOGE} -> %HOGE%
-- $HOGE   -> %HOGE%
-- 変換
local _filter = nyagos.filter
nyagos.filter = function(cmdline)
  local post = cmdline:gsub('${([%w_()]+)}', '%%%1%%')
  post = post:gsub('$([%w_()]+)', '%%%1%%')
  if (split(post, ' ')[1] == 'open') then
    post = post:gsub('/', '\\')
  end
  return _filter(post)
end

---------------------------------------------------------
-- ヒストリ検索&補完
function search_history(this, is_prev)
    -- カーソル位置が一番左の場合は通常のnext/prev
    if this.pos == 1 then
        if is_prev == true then
            this:call("PREVIOUS_HISTORY")
        else
            this:call("NEXT_HISTORY")
        end
        this:call("BEGINNING_OF_LINE")
        return nil
    end

    -- 検索キーワード
    local search_string = this.text:sub(1, this.pos - 1)

    -- 重複を除いたhistoryリストの取得
    local history_uniq = {}
    local is_duplicated = false
    local hist_len = nyagos.gethistory()
    for i = 1, hist_len do
        local history
        -- 新しい履歴がリスト後ろに残るよう末尾からサーチ
        history = nyagos.gethistory(hist_len - i)
        for i, e in ipairs(history_uniq) do
            if history == e or history == search_string then
                is_duplicated = true
            end
        end
        if is_duplicated == false then
            if is_prev == true then
                table.insert(history_uniq, history)
            else
                table.insert(history_uniq, 1, history)
            end
        end
        is_duplicated = false
    end

    -- 入力と完全一致する履歴を探す
    -- 完全一致する履歴を起点にすることで
    -- (見かけ上)インクリメンタルな検索にする
    local hist_pos = 0
    for i, e in ipairs(history_uniq) do
        if e == this.text then
            hist_pos = i
            break
        end
    end

    -- 前方一致する履歴を探す
    local matched_string = nil
    for i = hist_pos + 1, #history_uniq-2 do
        if history_uniq[i]:match('^' .. search_string .. '.*') then
            matched_string = history_uniq[i]
            break
        end
    end

    -- 見つかった履歴を出力
    -- 見つからなければ、検索キーワードを出力
    this:call("KILL_WHOLE_LINE")
    if (matched_string ~= nil) then
        this:insert(matched_string)
    else
        this:insert(search_string)
    end
    this:call("BEGINNING_OF_LINE")
    for i = 1, this.pos - 1 do
        this:call("FORWARD_CHAR")
    end
end

------------------------------------------------
-- $PATHとaliasを全てサーチするwhich
function nocd5_which(args)
    if #args == 0 then
        return
    end
    for i, arg in ipairs(args) do
        found = false
        aliased = getAliasedCommand(arg)
        if aliased ~= nil then
            print(arg .. ": aliased to " .. aliased)
            found = true
        end
        for k, ext in ipairs(split(string.lower(nyagos.getenv("PATHEXT")), ";")) do
            if arg:find('[/\\]') then
                if fileExists(arg .. ext) then
                    print((arg .. ext):gsub("\\", "/"))
                    found = true
                end
            else
                paths = split(nyagos.getenv("PATH"), ";")
                table.insert(paths, 1,".")
                for j, path in ipairs(paths) do
                    if fileExists(path .. "/" .. arg .. ext) then
                        print((path .. "/" .. arg .. ext):gsub("\\", "/"))
                        found = true
                    end
                end
            end
        end
        if found ~= true then
            print("exec: \"" .. arg .. "\": executable file not found in %PATH%")
        end
    end
end
function getAliasedCommand(key)
    for i, e in pairs(split(nyagos.eval("alias"),'[\r\n]')) do
        alias = split(e, '=')
        if key == alias[1] then
            return alias[2]
        end
    end
    return nil
end
function fileExists(name)
    fp, e = io.open(name, "r")
    if e == nil then
        io.close(fp)
        return true
    end
    return false
end

function getHome()
    return nyagos.getenv("HOME") or nyagos.getenv("USERPROFILE")
end
-- vim:set ft=lua: --
