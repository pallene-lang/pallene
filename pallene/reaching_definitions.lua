
local ir = require "pallene.ir"
local inspect = require "inspect"

local RD = {}
-- start set operations -----------

local ppi = function(t,f) return inspect(t,{newline='',process=f}) end
local pp = function(t,f) return inspect(t,{process=f}) end

local function copy(t1,t2)
    for k,v in pairs(t2) do t1[k] = v end
end
local function deduplicate(t)
    local hash = {}
    local res = {}
    for _,v in ipairs(t) do
       if not hash[v] then
           res[#res+1] = v
           hash[v] = true
       end
    end
    return res
end
local function union(t1, t2)
    local ret = {}
    for _,v in ipairs(t1) do
        table.insert(ret,v)
    end
    for _,v in ipairs(t2) do
        table.insert(ret,v)
    end
    return deduplicate(ret)
end
local function difference(t1,t2)
    local ret = {}
    local hash = {}
    for _,v in ipairs(t2) do
       if not hash[v] then
           hash[v] = true
       end
    end
    for _,v in ipairs(t1) do
        if not hash[v] then
            table.insert(ret,v)
        end
    end
    return ret
end
local function equal(t1,t2)
    if #t1 ~= #t2 then return false end
    local h1,h2 = {},{}
    for k,v in ipairs(t1) do
       if not h1[v] then
           h1[v] = true
       end
       if not h2[t2[k]] then
           h2[t2[k]] = true
       end
    end
    for k,_ in pairs(h1) do
        if not h2[k] then return false end
    end
    return true
end


-- end   set operations -----------

-- start control flow -------------
local function newnode(cmd,cfg,parent)
    table.insert(cfg,{
        cmd = cmd,
        to={},
        from=parent
    })
    for _,par in ipairs(parent) do
        if par > 0 then
            table.insert(cfg[par].to,#cfg)
        end
    end
    return {#cfg}
end
local function build_cfg(cmd,cfg,parent)
    local tag = cmd._tag
    if     tag == "ir.Cmd.Nop" then
        --nothing
    elseif tag == "ir.Cmd.Seq" then
        local newidx = parent
        for _, c in ipairs(cmd.cmds) do
            newidx = build_cfg(c,cfg,newidx)
        end
        return newidx
    elseif tag == "ir.Cmd.If" then
        local newidx = build_cfg(cmd.condition,cfg,parent)
        local then_ = build_cfg(cmd.then_,cfg,newidx)
        local else_ = build_cfg(cmd.else_,cfg,newidx) 
        return union(then_,else_)
    elseif tag == "ir.Cmd.Loop" then
    elseif tag == "ir.Cmd.For" then
        local newidx = parent
        newidx = build_cfg(cmd.start,cfg,newidx)
        newidx = build_cfg(cmd.limit,cfg,newidx)
        newidx = build_cfg(cmd.step,cfg,newidx)
        newidx = build_cfg(cmd.body,cfg,newidx)
        return newidx
    elseif string.match(tag, "^ir%.Cmd%.") then
        return newnode(cmd,cfg,parent)
    elseif string.match(tag, "^ir%.Value%.") then
        return parent
    end
end
local function traversecfg(cfg,index,fs,input)
    for _,v in ipairs(fs) do v(index, cfg,input) end
    if type(cfg) ~= 'table' or not cfg[index] then return end
    for _,v in ipairs(cfg[index].to) do
           traversecfg(cfg,v,fs,input)
    end
end
local function check_unreachable(index, cfg, df)
    local node = cfg[index]
    if node then
        local unreachable = 0
        for _,parent in ipairs(node.from) do
            if cfg[parent] then
                local tag = cfg[parent].cmd._tag
                if tag == "ir.Cmd.Return" or tag == "ir.Cmd.Break" then
                    unreachable = unreachable + 1
                end
            end
        end
        if unreachable ==  #node.from and #node.from ~= 0 then
            if node.cmd.loc then
                df.unreachable[node.cmd.loc.line] = true
            else
                print('ERROR: unreachable code without lineinfo')
            end 
        end
    end
end
local function cfg2dot(cfg)
    print([[ digraph cfg { 
        0 [label="Entry"];]])
    local visited = {}
    traversecfg(cfg,1,{function(index,cfg_)
        local n = cfg_[index]
        if n and not visited[n] then
            visited[n] = true
            print(index..' [label="'..n.cmd._tag..'"];')
            for _,f in ipairs(n.from) do 
                print(f..'->'..index..';')
            end
        end
    end})
    print('}')
end
-- end   control flow -------------
-- start definitions  -------------

local function find_defs_uses(index,cfg,i)
    local node = cfg[index] and cfg[index].cmd --  TODO: bb has only one statement
    if not node or type(node) ~= 'table' then return end
    for _, v_id in ipairs(ir.get_dsts(node)) do
        table.insert(i.definitions,{
            cmd = node,
            bb = index,
            line = node.loc and node.loc.line,
            var = v_id
           })
        if not i.vars[v_id] then
            i.vars[v_id] = {defs={},uses={},line=node.loc and node.loc.line}
        end
        table.insert(i.vars[v_id].defs,#i.definitions)
        for _, val in ipairs(ir.get_srcs(node)) do
            if val._tag == "ir.Value.LocalVar" then
                i.definitions[#i.definitions].value = val.id
                if not i.vars[val.id] then
                    i.vars[val.id] = {defs={},uses={}}
                end
                table.insert(i.vars[val.id].uses,#i.definitions)
            end
        end
    end
    for _, val in ipairs(ir.get_srcs(node)) do
        if val._tag == "ir.Value.LocalVar" then
            table.insert(i.uses,{
                cmd = node,
                var = val.id,
                bb = index,
            })
        end
    end
end
-- end   definitions  -------------
-- start gen/kill  -------------

local function find_gen_kill(index,cfg,i)
    local node = cfg[index] and cfg[index].cmd --  TODO: bb has only one statement
    if not node or type(node) ~= 'table' then return end
    i.GEN[index] = {}
    i.KILL[index] = {}
    for _, v_id in ipairs(ir.get_dsts(node)) do
        --table.insert(kill[index], all_defs(v_id)) -- - this
        copy(i.KILL[index], i.vars[v_id].defs)
    end
    for _, _ in ipairs(ir.get_srcs(node)) do
        --copy(gen[index], vars[val.id].uses) -- + this
        local thisdef = nil
        for k,v in ipairs(i.definitions) do
            if v.cmd == node then
                thisdef = k
            end
        end
        i.GEN[index] = {thisdef}
    end
end
-- end   gen/kill  -------------
-- start in/out    -------------
local function Upred(graph,index,out)
    local ret = {}
    for _,pred in pairs(graph[index].from) do
        ret = union(ret,out[pred])
    end
    return ret
end
local function find_in_out(cfg,df)
    for k,_ in pairs(cfg) do
        df.IN[k] = {}
        df.OUT[k] = {}
    end
    df.OUT[1] = {} -- RD
    local change = true
    local it = 0
    while change do
        it = it + 1
        change = false
        for k,_ in pairs(cfg) do
            if k > 0 then
                df.IN[k] = Upred(cfg,k,df.OUT) --RD
                local oldOUT = df.OUT[k]
                --OUT[k] = (IN[K] - kill[K]) + gen[K] --RD
                df.OUT[k] = union(difference(df.IN[k],df.KILL[k]),df.GEN[k])
                --if oldOUT ~= OUT[k] then 
                if not equal(oldOUT, df.OUT[k]) then
                    change = true
                end
            end
        end
    end
end
-- end   in/out    -------------
-- start analyses  -------------

-- variable not declared:
-- if a use of a variable doesn't reach any of its definitions, it is undeclared
local function undeclared_unused_vars(df)
    -- trivial cases
    for k,v in pairs(df.vars) do
        if equal(v.defs,{}) then
            df.undeclared[k] = v.line
        end
        if equal(v.uses,{}) then
            df.unused[k] = v.line
        end
    end
    local unused = difference(df.OUT[#df.OUT],df.IN[#df.IN])
    for _,v in ipairs(unused) do
        df.unused[df.definitions[v].var] = df.definitions[v].line
        --print(df.definitions[v].var, 'unused on bb',df.definitions[v].bb)
    end
end
-- shadowing:
-- if a definition reaches another definition
--    if the last OUT doesnt contain all the defs, the difference was shadowed
local function shadowing(df)
      local temp = {}
      copy(temp,df.OUT[#df.OUT])
      table.sort(temp)
      local t2 = {}
      for i=1,#temp do
        table.insert(t2,i)
      end
      local t3 = difference(t2,temp)
      for _,v in ipairs(t3) do
        df.shadowed[df.definitions[v].var] = df.definitions[v].line
        --print(df.definitions[v].var,'was shadowed on basic block',df.definitions[v].bb)
      end
end
-- end   analyses  -------------

function RD.run(module)

    local errors = {}
    for _, func in ipairs(module.functions) do
        local CFG = {}
        --print(pp(func.body))
        build_cfg(func.body,CFG,{0})
        if CFG[1] then
            --cfg2dot(CFG)
            CFG[1].from = difference(CFG[1].from,{0})
            --print(pp(CFG))
            local df = {}
            df.vars = {}
            df.uses = {}
            df.definitions = {}
            df.unreachable = {}
            traversecfg(CFG,1,{check_unreachable},df)
            for k,_ in pairs(df.unreachable) do
                print('unreachable code on line',k)
            end
            traversecfg(CFG,1,{find_defs_uses},df)
            -- print('vars defs/uses')
            -- for k,v in pairs(df.vars) do
            --     print(k,ppi(v.defs),ppi(v.uses))
            -- end
            -- print('defs')
            -- for k,v in pairs(df.definitions) do
            --     print(k,v.var, v.bb)
            -- end

            -- print('uses')
            -- for k,v in pairs(df.uses) do
            --     print(k,v.var, v.bb)
            -- end
            df.GEN = {}
            df.KILL = {}
            traversecfg(CFG,1,{find_gen_kill},df)
            -- print('gen/kill')
            -- for k,_ in pairs(CFG) do
            --     print(k,ppi(df.GEN[k]),ppi(df.KILL[k]))
            -- end
            df.IN = {}
            df.OUT = {}
            find_in_out(CFG,df)
            -- print('IN/OUT')
            -- for k,_ in pairs(CFG) do
            --     print(k, ppi(df.IN[k]),ppi(df.OUT[k]))
            -- end
            df.unused = {}
            df.undeclared = {}
            undeclared_unused_vars(df)
            for k,v in pairs(df.unused) do
                print('unused',func.vars[k].name,'on line ',v)
            end
            for k,v in pairs(df.undeclared) do
                print('undeclared',func.vars[k].name,'on line ',v)
            end
            df.shadowed = {}
            shadowing(df)
            for k,v in pairs(df.shadowed) do
                print(func.vars[k].name,'on line ',v,'is shadowed')
            end
        end
    end

    if #errors == 0 then
        return module, {}
    else
        return false, errors
    end
end

return RD


