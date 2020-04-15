
local ir = require "pallene.ir"
local location = require "pallene.location"

--local inspect = require "inspect"
--local ppi = function(t,f) return inspect(t,{newline='',process=f}) end
--local pp = function(t,f) return inspect(t,{process=f}) end

local RD = {}
-- start set operations -----------
local Set = {}
function Set.copy(t1,t2)
    for k,v in ipairs(t2) do t1[k] = v end
end
function Set.deduplicate(t)
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
function Set.union(t1, t2)
    local ret = {}
    for _,v in ipairs(t1) do
        table.insert(ret,v)
    end
    for _,v in ipairs(t2) do
        table.insert(ret,v)
    end
    return Set.deduplicate(ret)
end
function Set.difference(t1,t2)
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
function Set.equal(t1,t2)
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
-- start stack operations ---------
local Stack = {}
function Stack.push(t,elem)
    t[#t+1] = elem
end
function Stack.top(t)
    return t[#t]
end
function Stack.pop(t)
    local ret = t[#t]
    t[#t] = nil
    return ret
end
function Stack.copy(t1,t2)
    for k,v in ipairs(t2) do t1[k] = v end
end
-- end   stack operations ---------
-- start control flow -------------
local CFG = {}
--[[
    A control flow graph is a representation of all paths 
    that might be traversed through a program execution. 
    
    The nodes represent commands that use or alter data 
    and the edges represent control instructions.

    In this module, each node is defined by two sets of node indices (from and to)
    and a list of commands. These commands are pointers to nodes in the ir module.

    All the commands of the list are one of the listed in the ir module
    except for the control flow ones (Nop, Seq, Return, Break, Loop, If and For).

    Values aren't nodes.

--]]
function CFG:new(code)
    local new = {}
    setmetatable(new, self)
    self.__index = self
    -- exit node
    new[-1] = {cmd = false, to={},from={}}
    -- entry node
    new[0] = {cmd = false, to={},from={}}
    if code then
        local ctx = CFG.new_ctx()
        -- set current node of new_ctx as 0
        ctx.current_node = {0}
        new:build(code,ctx)
    end
    return new
end
-- builds the graph and calls new_node.
-- it receives a node to analyze and the context until now.
-- it returns an updated context (a copy), see CFG.new_ctx
-- TODO:(discussion) receive a callback, since this treatment is language specific
function CFG:build(cmd,ctx)
    local tag = cmd._tag
    if     tag == "ir.Cmd.Nop" then
        return ctx
    elseif tag == "ir.Cmd.Seq" then
        local newctx = ctx
        for _, c in ipairs(cmd.cmds) do
            newctx = self:build(c,newctx)
        end
        return newctx
    elseif tag == "ir.Cmd.Return" then
        -- -1 means end of the function
        return self:new_edge({-1},ctx)
    elseif tag == "ir.Cmd.Break" then
        local loop = Stack.top(ctx.current_loop)
        assert(loop,'break outside loop (should be impossible)')
        return self:new_edge(loop, ctx)
    elseif tag == "ir.Cmd.Loop" then
        Stack.push(ctx.current_loop, {})
        --print('create new loop',#ctx.current_loop)
        local newctx = self:build(cmd.body,ctx)
        -- at the end of the loop, gets all indexes at the top 
        -- and makes them point to the next (TODO)
        -- will have to change the edge logic on break
        Stack.pop(newctx.current_loop)
        return newctx
    elseif tag == "ir.Cmd.If" then
        -- condition is an ir.Value and 
        -- will be extracted to an assignment instruction beforehand
        local then_ = cmd.then_ and self:build(cmd.then_,ctx) or {}
        local else_ = cmd.else_ and self:build(cmd.else_,ctx) or {}
        return CFG.ctx_union(then_,else_)
    elseif tag == "ir.Cmd.For" then
        -- start,limit,step are ir.Value and 
        -- will be extracted to assignments beforehand
        Stack.push(ctx.current_loop, ctx.current_node)
        local newctx = self:build(cmd.body,ctx)
        Stack.pop(newctx.current_loop)
        return newctx
    elseif string.match(tag, "^ir%.Cmd%.") then
        return self:new_node(cmd,ctx)
    else
        return ctx
    end
end
-- returns a copy of the context
-- a context has:
--     current_node : set<index>,  
--     current_loop : stack<index>
function CFG.new_ctx(ctx)
    local new = {}
    new.current_node = {}
    new.current_loop = {}
    if ctx then
        Set.copy(new.current_node,ctx.current_node)
        Stack.copy(new.current_loop,ctx.current_loop)
    end
    return new
end
--performs union on two contexts, returning a new one
function CFG.ctx_union(ctx1,ctx2)
    local new = {}
    new.current_node = Set.union(ctx1.current_node,ctx2.current_node)
    --TODO: assert that the loop ended? 
    new.current_loop = Set.union(ctx1.current_loop,ctx2.current_loop)
    return new
end
-- creates a new node, should only be called to non-control commands.
-- returns an updated context
function CFG:new_node(cmd,ctx)
    table.insert(self,{
        cmd = cmd, --TODO should be a list of commands
        to={},
        from={}
    })
    local new_node_id = #self
    local new_node = self[new_node_id]
    Set.copy(new_node.from, ctx.current_node)
    for _,from in ipairs(new_node.from) do
            table.insert(self[from].to,new_node_id)
    end
    local newctx = CFG.new_ctx(ctx)
    newctx.current_node = {new_node_id}
    return newctx
end
-- creates a new edge from each of the current nodes to each of the target nodes
function CFG:new_edge(target,ctx)
    for _,from in ipairs(ctx.current_node) do
        for _,to in ipairs(target) do
            table.insert(self[from].to,to)
            table.insert(self[to].from,from)
        end
    end
    return ctx
end

-- traverses the CFG applying the array of functions fs with the input to each node.
function CFG:traverse(index,fs,input,visited)
    visited = visited or {}
    visited[index] = true
    for _,v in ipairs(fs) do v(self,index,input) end
    assert(self[index], 'failed to retrieve node at index '..index)
    for _,v in ipairs(self[index].to) do
        -- dont go to entry or exit nodes
        if v > 0 and not visited[v] then
            self:traverse(v,fs,input,visited)
        end
    end
end
-- a dead code analysis at CFG level:
-- If a node's from is empty, 
-- then the node isn't reachable.
-- returns a set of localizations of unreachable code in the ret input.
-- if it returns ret[true] as unreachable, 
-- it means that the exit node is unreachable,
-- meaning that maybe there is an inifinite loop in the function.
function CFG:check_unreachable(index, ret)
    local node = self[index]
    if node then
        if #node.from == 0 then
            if node.cmd.loc then
                ret[node.cmd.loc] = true
            else
                error('impossible',node._tag)
            end 
        end
    end
end
function CFG:unreachable()
    local ret = {}
    self:traverse(1,{CFG.check_unreachable},ret)
    if #self[-1].from ~= 0 then
        ret[true] = true
    end
    return ret
end
-- converts the CFG to DOT format, which can be redered with the graphviz utility.
function CFG:to_dot()
    print(' digraph cfg {')
    print('0 [label="Entry"];')
    print('-1 [label="Exit"];')
    local visited = {}
    self:traverse(1,{function(index,cfg_)
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
--]]
-- end   control flow -------------
-- start definitions  -------------

local function find_defs_uses(cfg,index,i)
    --  TODO: bb has only one statement
    local node = cfg[index] and cfg[index].cmd 
    if not node or type(node) ~= 'table' then return end
    for _, v_id in ipairs(ir.get_dsts(node)) do
        table.insert(i.definitions,{
            cmd = node,
            bb = index,
            loc = node.loc,
            var = v_id
           })
        if not i.vars[v_id] then
            i.vars[v_id] = {defs={},uses={},loc=node.loc}
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

local function find_gen_kill(cfg,index,i)
    -- valid nodes have positive indexes, 0 and -1 are entry and exit nodes
    if index <= 0 then return end
    local node = cfg[index] and cfg[index].cmd --  TODO: bb has only one statement
    assert(node,'no node at index '..index)
    i.GEN[index] = {}
    i.KILL[index] = {}
    for _, v_id in ipairs(ir.get_dsts(node)) do
        --table.insert(kill[index], all_defs(v_id)) -- - this
        Set.copy(i.KILL[index], i.vars[v_id].defs)
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
        ret = Set.union(ret,out[pred])
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
    while change do
        change = false
        for k,_ in ipairs(cfg) do
            df.IN[k] = Upred(cfg,k,df.OUT) --RD
            local oldOUT = df.OUT[k]
            --OUT[k] = (IN[K] - kill[K]) + gen[K] --RD
            df.OUT[k] = Set.union(Set.difference(df.IN[k],df.KILL[k]),df.GEN[k])
            --if oldOUT ~= OUT[k] then 
            if not Set.equal(oldOUT, df.OUT[k]) then
                change = true
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
        if Set.equal(v.defs,{}) then
            df.undeclared[k] = v.loc
        end
        if Set.equal(v.uses,{}) then
            df.unused[k] = v.loc
        end
    end
    local unused = Set.difference(df.OUT[#df.OUT],df.IN[#df.IN])
    for _,v in ipairs(unused) do
        df.unused[df.definitions[v].var] = df.definitions[v].loc
        --print(df.definitions[v].var, 'unused on bb',df.definitions[v].bb)
    end
end
-- shadowing:
-- if a definition reaches another definition
--    if the last OUT doesnt contain all the defs, the difference was shadowed
local function shadowing(df)
      local temp = {}
      Set.copy(temp,df.OUT[#df.OUT])
      table.sort(temp)
      local t2 = {}
      for i=1,#temp do
        table.insert(t2,i)
      end
      local t3 = Set.difference(t2,temp)
      for _,v in ipairs(t3) do
        df.shadowed[df.definitions[v].var] = df.definitions[v].loc
        --print(df.definitions[v].var,'was shadowed on basic block',df.definitions[v].bb)
      end
end
-- end   analyses  -------------

function RD.run(module)

    local errors = {}
    for _, func in ipairs(module.functions) do
        local cfg = CFG:new(func.body)        
        -- if the graph is not empty
        if cfg[1] then
            local df = {}
            df.unreachable = cfg:unreachable()
            for k,_ in pairs(df.unreachable) do
                if k == true then 
                    table.insert(errors, location.format_error(func.loc,'unreachable code, possible infite loop'))
                else
                    table.insert(errors, location.format_error(k,'unreachable code'))
                end
            end
            df.vars = {}
            df.uses = {}
            df.definitions = {}
            cfg:traverse(1,{find_defs_uses},df)
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
            cfg:traverse(1,{find_gen_kill},df)
            for k,_ in ipairs(cfg) do
                assert(type(df.GEN[k])=='table','no GEN at '..k)
                assert(type(df.KILL[k])=='table','no KILL at '..k)
            end
            -- print('gen/kill')
            -- for k,_ in pairs(CFG) do
            --     print(k,ppi(df.GEN[k]),ppi(df.KILL[k]))
            -- end
            df.IN = {}
            df.OUT = {}
            find_in_out(cfg,df)
            -- print('IN/OUT')
            -- for k,_ in pairs(CFG) do
            --     print(k, ppi(df.IN[k]),ppi(df.OUT[k]))
            -- end
            df.unused = {}
            df.undeclared = {}
            undeclared_unused_vars(df)
            for k,v in pairs(df.unused) do
                if func.vars[k].name and not (func.vars[k].name == "ret1") then
                    table.insert(errors, location.format_error(v,func.vars[k].name..' unused'))
                end
            end
            for k,v in pairs(df.undeclared) do
                table.insert(errors, location.format_error(v,func.vars[k].name..' undeclared'))
            end
            df.shadowed = {}
            shadowing(df)
            for k,v in pairs(df.shadowed) do
                if func.vars[k].name and not (func.vars[k].name == "ret1") then
                    table.insert(errors, location.format_error(v,func.vars[k].name..' is shadowed'))
                end
            end
        end
    end
-- supressing errors for now
--[[
    if #errors == 0 then
        return module, {}
    else
        return false, errors
    end
--]]
    return module, {}
end

return RD


