share.directory_stack = {}
share.migemo_dict = 'C:/Tools/bin/dict/utf-8/migemo-dict'
share.luamigemo = nil

share.print = function(s)
    nyagos.write(s)
    nyagos.write('\n')
end

------------------------------------------------
-- ディレクトリ移動時にPROMPTを変更する
--
-- makePrompt()が重い(特にネットワークドライブ上など)ので
-- ディレクトリ移動時にのみPROMPTを更新
-- share.UpdatePromptAlways = false
-- 右プロンプト表示のため(位置、ブランチの変更に追従)
-- 常にプロンプトを更新
share.UpdatePromptAlways = true

share.prompt = nyagos.prompt
share.PROMPT = ''
share.cd = function(arg)
    r, err = nyagos.exec('__cd__ "' .. arg:gsub('\\', '/') .. '"')
    if (not share.UpdatePromptAlways) then
        share.PROMPT = share.makePrompt()
    end
    return r, err
end

nyagos.prompt = function(template)
    if (share.UpdatePromptAlways) then
        return share.prompt(share.makePrompt())
    else
        if (share.PROMPT == '') then
            share.PROMPT = share.makePrompt()
        end
        return share.prompt(share.PROMPT)
    end
end

------------------------------------------------
-- PROMPT生成部分
share.makePrompt = function()
    local prompt = '$e[30;40;1m[' .. share.getCompressedPath(3):gsub('\\', '/') .. ']$e[37;1m'
    local rprompt = ''
    local hgbranch = share.getBranch().HgBranch
    local gitbranch = share.getBranch().GitBranch
    if (hgbranch ~= nil) then
        rprompt = rprompt .. '$e[30;40;1m[$e[33;40;1m' .. hgbranch .. '$e[30;40;1m]$e[37;1m'
    end
    if (gitbranch ~= nil) then
        rprompt = rprompt .. '$e[30;40;1m[$e[33;40;1m' .. gitbranch .. '$e[30;40;1m]$e[37;1m'
    end
    pad = nyagos.getviewwidth() - share.getStringWidth(share.removeEscapeSequence(prompt .. rprompt))
    for i = 1, pad-1 do
        prompt = prompt .. ' '
    end
    return prompt .. rprompt .. '\n$ '
end

------------------------------------------------
-- 最下層nのディレクトリ名だけ表示する文字列生成
share.getCompressedPath = function(num)
    local path = nyagos.getwd()
    local buff = path

    local drive = nil

    -- HOME以下の場合
    local home = share.getHome()
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

    local tbl = share.split(buff, "[\\/]")
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
-- Mercurial, Gitのブランチ名を取得
share.getBranch = function()
    local dir = '.'
    branch = {
        HgBranch = nil,
        GitBranch = nil
    }
    while true do
        local hgrepo = nyagos.stat(dir .. '/.hg')
        local gitrepo = nyagos.stat(dir .. '/.git')
        if hgrepo then
            if hgrepo.isdir then
                local fp = io.open(dir .. '/.hg/branch', 'r')
                if fp then
                    branch.HgBranch = fp:read()
                    fp:close()
                else
                    branch.HgBranch = 'default'
                end
                break
            end
        elseif gitrepo then
            if gitrepo.isdir then
                local fp = io.open(dir .. '/.git/HEAD', 'r')
                if fp then
                    local head = fp:read()
                    fp:close()
                    if head:match('ref: (%w+)') then
                        branch.GitBranch = head:gsub('ref: (%w+)', '%1')
                    else
                        local fp = io.open(dir .. '/.git/packed-refs', 'r')
                        if fp then
                            local line = fp:read()
                            while line do
                                if not line:match('^#.*') then
                                    local ref = share.split(line, ' ')
                                    if ref[1] == head then
                                        branch.GitBranch = ref[2]
                                    end
                                end
                                line = fp:read()
                            end
                            fp:close()
                        end
                        if not branch.GitBranch then
                            branch.GitBranch = 'detached from ' .. head:sub(1, 7)
                        end
                    end
                    break
                end
                break
            end
        end
        if nyagos.stat(dir) == nil then
            return branch
        end
        dir = dir .. '/..'
    end
    return branch
end

------------------------------------------------
-- ユーザーのホームディレクトリを返す
share.getHome = function()
    return nyagos.getenv("HOME") or nyagos.getenv("USERPROFILE")
end

------------------------------------------------
-- strをpatで分割しテーブルを返す
-- base code from 'http://lua-users.org/wiki/SplitJoin'
share.split = function(str, pat)
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
-- 文字列の幅を取得
-- 半角文字:1, 全角文字:2 にカウント
share.getStringWidth = function(src)
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

------------------------------------------------
-- エスケープシーケンスを除いた文字列を返す
share.removeEscapeSequence = function(src)
    return src:gsub('$e%[%d+;%d+;1m',''):gsub('$e%[%d+;1m','')
end

------------------------------------------------
-- pushd
share.nocd5_pushd = function(args)
    local directory_stack = share.directory_stack
    local old = nyagos.getwd()
    if #args >= 1 then
        r, err = share.cd(args[1])
    else
        r, err = share.cd(share.getHome())
    end
    if err == nil then
        table.insert(directory_stack, 1, old)
    else
        return r, err
    end
    share.directory_stack = directory_stack
end
------------------------------------------------
-- popd
share.nocd5_popd = function(args)
    local directory_stack = share.directory_stack
    if #directory_stack ~= 0 then
        local num = 0
        if #args == 0 then
            num = 1
        else
            num = tonumber(args[1])
        end
        share.cd(directory_stack[num])
        table.remove(directory_stack, num)
    else
        print('popd: directories stack is empty.')
    end
    share.directory_stack = directory_stack
end
------------------------------------------------
-- dirs
share.nocd5_dirs = function()
    max_len = string.len(tostring(#share.directory_stack))
    for i, e in ipairs(share.directory_stack) do
        len = string.len(tostring(i))
        share.print(string.rep(' ', max_len - len) .. '\027[32;;1m' .. i .. '\027[;;0m : ' .. e)
    end
end
------------------------------------------------

------------------------------------------------
-- インタラクティブなディレクトリ移動
share. nocd5_icd = function(args)
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
            local directories = share.getDirectoryList(parent, pattern)
            if #directories == 0 then
                print(pattern .. ': No such directory')
            elseif #directories == 1 then
                target = {directories[1]}
            else
                max_len = string.len(tostring(#directories))
                for i, e in ipairs(directories) do
                    len = string.len(tostring(i))
                    share.print(string.rep(' ', max_len - len) .. '\027[32;;1m' .. i .. '\027[;;0m : ' .. e)
                end

                local index = share.getIndex()
                if #directories < index then
                    print(index .. ': Invalid index')
                elseif 0 < index then
                    target = {directories[index]}
                end
            end
        end
    end
    if target ~= nil then
        share.nocd5_pushd(target)
    end
end
------------------------------------------------
-- ディレクトリのリストを取得
share.getDirectoryList = function(parent, pattern)
    if parent:find('^[\\/].*') then
        if not(parent:find('^[\\/][\\/]+')) then
            parent = nyagos.getwd():gsub('[\\/].*', '') .. parent:gsub('\\', '/')
        end
    end
    local line = nyagos.eval('ls -lar ' .. parent) -- nyagos組み込みの`ls`
    local complst = share.split(line, '[\r\n]')
    local directories = {}
    for i, e in ipairs(complst) do
        local name = tostring(e:gsub(".-%s+", "", 4))
        -- 末尾が'/'ならディレクトリって事で決め打ち
        if share.getMatchingDirectory(name, pattern) then
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
-- キーボード入力から数字を取得
share.GETINDEX_NO_INPUT = -1
share.GETINDEX_ABORT    = -2
share.getIndex = function()
	nyagos.write('> ')
	local index = share.GETINDEX_NO_INPUT -- 戻り値
	local stridx = ""
	local charcnt = 0
	while(1) do
        local key = nyagos.getkey()
		local c = string.char(key)
		nyagos.write(string.rep('\b \b',#stridx)) -- 毎回表示を初期化し、最後に今までの入力結果を表示

		if (c == '\r') then
			break
		elseif (c == '') then
			index = share.GETINDEX_ABORT
			break
		elseif (c == '\b') then -- BACKSPACEの時は1ダウンカウント
			charcnt = charcnt == 0 and 0 or charcnt - 1 -- ただし  0 ≦ charcnt
			stridx = stridx:sub(1,#stridx-1)
		elseif (c:match('%d')) then
			stridx = stridx .. c
			charcnt = charcnt + 1
		end

		-- -- maxlenに達したら終了
		-- if (maxlen ~= -1 and maxlen <= charcnt) then
		-- 	break
		-- end

		nyagos.write(stridx)
	end

	if (stridx ~= nil and (stridx ~= "")) then
		nyagos.write(stridx .. '\n')
		index = tonumber(stridx)
	else
		nyagos.write('\n')
	end

	return index
end

---------------------------------------------------------
-- luamigemo関係
share.getLuamigemo = function()
    if share.luamigemo == nil then
        share.luamigemo = require('luamigemo')
        share.luamigemo.open(share.migemo_dict, "UTF-8")
    end
    return share.luamigemo
end
-- 条件に一致する名前を返す
share.getMatchingDirectory = function(name, pattern)
    local result = false
    if name:match('.*/$') then
        local luamigemo = share.getLuamigemo()
        -- 正規表現に渡すパターンの下準備
        local strcf = ''
        local strque = ''
        strcf = pattern:sub(0):match('%u') and '' or 'i' -- 最初の文字が小文字ならignorecase
        result = luamigemo.migematch(pattern, name, strcf) == 0
    end
    return result
end
---------------------------------------------------------

------------------------------------------------
-- pecoを使ったディレクトリ移動
share.nocd5_pcd = function(args)
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
    local directories = share.getDirectoryList(parent, pattern)
    if #directories == 0 then
        print(pattern .. ': No such directory')
    else
        local dir = nyagos.eval("echo " .. table.concat(directories, '\n') ..  " | peco")
        if dir ~= nil then
            share.nocd5_pushd({ share.chomp(dir) })
        end
    end
end
------------------------------------------------

------------------------------------------------
-- srcの末尾から改行を取り除く
share.chomp = function(src)
    return string.gsub(src, "[\r\n]+$", "")
end

----------------------------------------------------------
-- gookmark Front End
share.nocd5_pgm = function(args)
    local target = nyagos.eval('gookmark list | peco')
    if target ~= nil and target ~= "" then
        if share.is_dir(target) then
            share.nocd5_pushd({ target })
        else
            nyagos.exec('open ' .. target)
        end
    end
end
share.nocd5_pga = function(args)
    local target = nyagos.eval('gookmark list --group app | peco')
    if target ~= nil and target ~= "" then
        if share.is_dir(target) then
            share.nocd5_pushd({ target })
        else
            nyagos.exec('open ' .. target)
        end
    end
end
share.nocd5_pgf = function(args)
    local target = nyagos.eval('gookmark list --group file | peco')
    if target ~= nil and target ~= "" then
        if share.is_dir(target) then
            share.nocd5_pushd({ target })
        else
            nyagos.exec('open ' .. target)
        end
    end
end
share.nocd5_dot = function(args)
    local target = nyagos.eval('gookmark list --group dot | peco')
    if target ~= nil and target ~= "" then
        if share.is_dir(target) then
            share.nocd5_pushd({ target })
        else
            nyagos.exec('vim ' .. target)
        end
    end
end
-- 
share.is_dir = function(f)
    return nyagos.stat(f).isdir
end
----------------------------------------------------------

share.nocd5_ppt = function(args)
    local sel = nyagos.eval('pt /column /columnasrune ' .. table.concat(args, ' ') ..  '| peco')
    if (#sel == 0) then
        return
    end
    local file, line, column = sel:match('(.*):(%d+):(%d+)')
    if ((file and line and column) == nil) then
        print("Error : Invalid format")
        print(" -> " .. sel)
        return
    end
    nyagos.exec('gvim.exe ' .. file .. ' +' .. line ..
                ' -c \":normal 0\"' .. ' -c \":normal ' .. tonumber(column) - 1 .. 'l\" &')
end

nyagos.on_command_not_found = function(args)
    local cand = {}
    for i, e in pairs(share.makeCandidates(args[0])) do
        if (nyagos.which(e)) then
            table.insert(cand, e)
        end
    end
    if (#cand > 0) then
        share.print('もしかして...')
        for i, e in pairs(cand) do
            share.print('\027[32;;1m' .. i .. '\027[;;0m : ' .. e)
        end
        local index = share.getIndex()
        if #cand < index then
            share.print(index .. ': Invalid index')
        elseif 0 < index then
            share.print(cand[index] .. ' ' .. table.concat(args, ' '))
            nyagos.exec(cand[index] .. ' ' .. table.concat(args, ' '))
        end
        return true
    end
    return false
end
share.makeCandidates = function(src)
    local result = {}

    local tbl = {}
    for p, c in utf8.codes(src) do
        table.insert(tbl, utf8.char(c))
    end
    for i = 1, string.len(src) - 1 do
        local tmp = table.pack(table.unpack(tbl))
        table.insert(tmp, i+2, tmp[i])
        table.remove(tmp, i)
        table.insert(result, table.concat(tmp))
    end
    return result
end

------------------------------------------------
-- $PATHとaliasを全てサーチするwhich
share.nocd5_which = function(args)
    if #args == 0 then
        return
    end
    for i, arg in ipairs(args) do
        found = false
        aliased = share.getAliasedCommand(arg)
        if aliased ~= nil then
            print(arg .. ": aliased to " .. aliased)
            found = true
        end
        for k, ext in ipairs(share.split(string.lower(nyagos.getenv("PATHEXT")), ";")) do
            if arg:find('[/\\]') then
                if share.fileExists(arg .. ext) then
                    local p = (arg .. ext):gsub("\\", "/")
                    print(p)
                    found = true
                end
            else
                paths = share.split(nyagos.getenv("PATH"), ";")
                table.insert(paths, 1, ".")
                for j, path in ipairs(paths) do
                    if share.fileExists(path .. "/" .. arg .. ext) then
                        local p = (path .. "/" .. arg .. ext):gsub("\\", "/")
                        print(p)
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
share.getAliasedCommand = function(key)
    for i, e in pairs(share.split(nyagos.eval("alias"), '[\r\n]')) do
        alias = share.split(e, '=')
        if key == alias[1] then
            return alias[2]
        end
    end
    return nil
end
share.fileExists = function(name)
    return nyagos.stat(name) ~= nil
end

---------------------------------------------------------
-- ${HOGE} -> %HOGE%
-- $HOGE   -> %HOGE%
-- 変換
share.filter = nyagos.filter
nyagos.filter = function(cmdline)
  local post = cmdline:gsub('${([%w_()]+)}', '%%%1%%')
  post = post:gsub('$([%w_()]+)', '%%%1%%')
  if (share.split(post, ' ')[1] == 'open') then
    post = post:gsub('/', '\\')
  end
  return share.filter(post)
end

---------------------------------------------------------
-- ヒストリ検索&補完
share.search_history = function(this, is_prev)
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
