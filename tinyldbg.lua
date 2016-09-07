--==============================================================================
-- tinyldbg
-- authored by Joe Del Rocco
--==============================================================================
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
--
-- http://www.opensource.org/licenses/mit-license.html
--==============================================================================


--=====================================
-- DEBUGGER DEFINED
--=====================================
tinyldbg =
{
    breakpoints = {},
    skiplines   = 0,
    funcindex   = -1
}

function tinyldbg.start()
    tinyldbg.breakpoints = {}
    tinyldbg.skiplines   = 0
    tinyldbg.funcindex   = -1
    print( "LUA DEBUGGER - Open." )
    debug.sethook( tinyldbg.hookline, "l" )
end

function tinyldbg.quit()
    debug.sethook()
    print( "LUA DEBUGGER - Closed." )
end

function tinyldbg.help()
    local l,r  = 21,48
    print( string.rep( "-", l+4+r ) )
    print( string.format( "  %" .. l .. "s > restart tinyldbg", "start" ) )
    print( string.format( "  %" .. l .. "s > shutdown tinyldbg", "quit" ) )
    print( string.format( "  %" .. l .. "s > continue until next breakpoint", "run" ) )
    print( string.format( "  %" .. l .. "s > step 1 or more lines", "step [number]" ) )
    print( string.format( "  %" .. l .. "s > step over the next function", "over" ) )
    print( string.format( "  %" .. l .. "s > loads a breakpoint config file", "loadb fname" ) )
    print( string.format( "  %" .. l .. "s > saves out current breakpoints to a file", "saveb fname" ) )
    print( string.format( "  %" .. l .. "s > defines a breakpoint", "setb fname line" ) )
    print( string.format( "  %" .. l .. "s > removes breakpoint at specified index", "rmb i" ) )
    print( string.format( "  %" .. l .. "s > enables breakpoint at specified index", "onb i" ) )
    print( string.format( "  %" .. l .. "s > disables breakpoint at specified index", "offb i" ) )
    print( string.format( "  %" .. l .. "s > enables or disables all breakpoints", "allb state" ) )
    print( string.format( "  %" .. l .. "s > lists all breakpoints", "listb" ) )
    print( string.format( "  %" .. l .. "s > removes all breakpoints", "clearb" ) )
    print( string.format( "  %" .. l .. "s > dumps local variables", "locals" ) )
    print( string.format( "  %" .. l .. "s > dumps upvalues variables", "upvals" ) )
    print( string.format( "  %" .. l .. "s > dumps function environment variables", "fenv" ) )
    print( string.format( "  %" .. l .. "s > dumps global variables", "globals" ) )
    print( string.format( "  %" .. l .. "s > dumps more info on specified function", "finfo [function name]" ) )
    print( string.format( "  %" .. l .. "s > dumps call stack", "trace" ) )
    print( string.format( "  %" .. l .. "s > displays the value of a variable", "get varname" ) )
    print( string.format( "  %" .. l .. "s > set variable to given string", "set varname, string" ) )
    print( string.format( "  %" .. l .. "s > set variable to given number", "seti varname, number" ) )
    print( string.format( "  %" .. l .. "s > creates new var with value of an existing var", "bind newvar oldvar" ) )
    print( string.format( "  %" .. l .. "s > executes 1 or more statements of lua", "lua statements" ) )
    print( string.rep( "-", l+4+r ) )
end

function tinyldbg.printtupletable( t )
    local i = 1
    print( string.rep( "-", t.w+6 ) )
    while true do
        if not t[i] then break end
        print( string.format( "%3s %" .. t.w .. "s > %s", i, t[i].n, t[i].v ) )
        i = i + 1
    end
    print( string.rep( "-", t.w+6 ) )
end

function tinyldbg.safehash( fname, line )
    fname = string.lower( fname )

    -- error check
    if not fname or not line then
        print( "  ..please specify a valid lua filename and line number!" )
        return nil
    end
    if string.sub( fname,-4,-1 ) ~= ".lua" then
        print( "  ..invalid extension for file '" .. fname .. "'." )
        return nil
    end
    if not tonumber( line ) then
        print( "  ..invalid line number '" .. tostring(line) .. "'." )
        return nil
    end

    -- remove unnecessary starting characters
    local chr = string.sub( fname,1,1 )
    while ( chr == '@' or chr == '/' or chr == '.' ) do
        fname = string.sub( fname,2,-1 )
        chr   = string.sub( fname,1,1 )
    end

    -- generate hash
    return ( string.sub( fname,1,-5 ) .. tostring( line ) )
end

function tinyldbg.safetostring( value )
    if type( value ) == "userdata" then
        return "USERDATA"
    else
        return tostring( value )
    end
end

function tinyldbg.getvariable( var, level )
    local i         -- counter
    local f         -- function
    local key, val  -- table hash key, value pair

    -- increment level of function stack since we are 1 function deeper
    level = level + 1

    -- search local table
    i = 1
    while true do
        key, val = debug.getlocal( level, i )
        if not key then break end
        if var == key then return val end
        i = i + 1
    end
    -- search upvals table
    f = debug.getinfo(level).func
    i = 1
    while true do
        key, val = debug.getupvalue( f, i )
        if not key then break end
        if var == key then return val end
        i = i + 1
    end
    -- search function environment
    f        = getfenv( debug.getinfo(level).func )
    key, val = next( f )
    while key do
        if var == key then return val end
        key, val = next( f, key )
    end
    -- search globals
    key, val = next( _G )
    while key do
        if var == key then return val end
        key, val = next( _G, key )
    end

    return nil
end

function tinyldbg.setvariable( var, newval, level )
    local i              -- counter
    local f              -- function
    local key            -- table key
    local found = false  -- boolean

    -- increment level of function stack since we are 1 function deeper
    level = level + 1

    -- search local table
    i = 1
    while not found do
        key = debug.getlocal( level, i )
        if not key then break end
        if var == key then
            debug.setlocal( level, i, newval )
            found = true
            break
        end
        i = i + 1
    end
    -- search upvals table
    f = debug.getinfo(level).func
    i = 1
    while not found do
        key = debug.getupvalue( f, i )
        if not key then break end
        if var == key then
            debug.setupvalue( f, i, newval )
            found = true
            break
        end
        i = i + 1
    end
    -- search function environment
    f   = getfenv( debug.getinfo(level).func )
    key = next( f )
    while not found and key do
        if var == key then
            f[var] = newval
            found  = true
            break
        end
        key = next( f, key )
    end
    -- search globals
    key = next( _G )
    while not found and key do
        if var == key then
            _G[var] = newval
            found   = true
            break
        end
        key = next( _G, key )
    end

    -- print results
    if found then
        print( "  ..set '" .. var .. "' to value '" .. tinyldbg.safetostring(newval) .. "'." )
    else
        print( "  ..no variable by the name '" .. var .. "'." )
    end
end

function tinyldbg.bindvariable( lhs, rhs )
    -- get variable to bind
    local rhsval = tinyldbg.getvariable( rhs, 4 )
    if not rhsval then
        print( " ..no variable by the name '" .. rhs .. "'." ) return
    end

    -- make new variable to bind to
    local f = loadstring( lhs .. " = 1" )
    setfenv( f, getfenv( debug.getinfo(4).func ) )
    xpcall( f, function(...) return(unpack(arg)) end )

    -- bind it
    tinyldbg.setvariable( lhs, rhsval, 4 )
end

function tinyldbg.dumplocals()
    local i = 1
    local t = { w = 0 }
    while true do
        local key, val = debug.getlocal( 4, i )
        if not key then break end
        t[i] = { n = key, v = tinyldbg.safetostring(val) }
        if string.len(key) > t.w then t.w = string.len(key) end
        i = i + 1
    end
    tinyldbg.printtupletable( t )
end

function tinyldbg.dumpupvals()
    local i = 1
    local t = { w = 0 }
    local f = debug.getinfo(4).func
    while true do
        local key, val = debug.getupvalue( f, i )
        if not key then break end
        t[i] = { n = key, v = tinyldbg.safetostring(val) }
        if string.len(key) > t.w then t.w = string.len(key) end
        i = i + 1
    end
    tinyldbg.printtupletable( t )
end

function tinyldbg.dumpfenv()
    local i = 1
    local t = { w = 0 }
    local e = getfenv( debug.getinfo(4).func )
    local key, val = next( e )
    while val do
        t[i] = { n = key, v = tinyldbg.safetostring(val) }
        if string.len(key) > t.w then t.w = string.len(key) end
        i = i + 1
        key, val = next( e, key )
    end
    tinyldbg.printtupletable( t )
end

function tinyldbg.dumpglobals()
    local i = 1
    local t = { w = 0 }
    local key, val = next( _G )
    while val do
        t[i] = { n = key, v = tinyldbg.safetostring(val) }
        if string.len(key) > t.w then t.w = string.len(key) end
        i = i + 1
        key, val = next( _G, key )
    end
    tinyldbg.printtupletable( t )
end

function tinyldbg.dumpfunctioninfo( funcname )
    -- retrieve function information
    local info = {}
    if funcname then
        local f = tinyldbg.getvariable( funcname, 4 )
        if not f then
            print( " ..function '" .. funcname .. "' does not exist." )
            return
        else
            info = debug.getinfo( f, "flnSu" )
        end
    else
        info = debug.getinfo( 4, "flnSu" )
    end

    -- print it out
    local i = 1
    local t = { w = 0 }
    local key, val = next( info )
    while val do
        t[i] = { n = key, v = tinyldbg.safetostring(val) }
        if string.len(key) > t.w then t.w = string.len(key) end
        i = i + 1
        key, val = next( info, key )
    end
    tinyldbg.printtupletable( t )
end

function tinyldbg.dumpvariable( var )
    local val = tinyldbg.getvariable( var, 4 )
    if val then
        local t = {}
        t[1] = { n = var, v = tinyldbg.safetostring(val) }
        t.w  = string.len(var)
        tinyldbg.printtupletable( t )
    else
        print( "  ..no variable by the name '" .. var .. "'." )
    end
end

function tinyldbg.loadbreakpoints( filename )
    -- open file
    if not filename then return end
    local bpfile = io.open( filename )
    if not bpfile then return end

    -- load breakpoints
    while true do
        local args   = {}
        local buffer = bpfile:read("*l")
        if not buffer then break end
        for x in string.gfind( buffer, "%S+" ) do table.insert( args, tostring(x) ) end
        tinyldbg.setbreakpoint( tostring(args[1]), tonumber(args[2]), tonumber(args[3]) )
    end
    bpfile:close()
end

function tinyldbg.savebreakpoints( filename )
    -- open file
    if not filename then return end
    local bpfile = io.open( filename, "w" )
    if not bpfile then return end

    -- save breakpoints
    local key, val = next( tinyldbg.breakpoints )
    while val do
        local i,j    = string.find( key, "([%d]*)$" )
        local buffer = string.sub( key, 1, i-1 ) .. ".lua "
        buffer = buffer .. string.sub( key, i, j ) .. " " .. tostring( val )
        bpfile:write( buffer .. "\n" )
        key, val = next( tinyldbg.breakpoints, key )
    end
    bpfile:close()
    print( "  ..breakpoints saved." )
end

function tinyldbg.setbreakpoint( fname, line, state )
    local key = tinyldbg.safehash( fname, line )
    if not key then return end
    if tinyldbg.breakpoints[ key ] == nil then
        tinyldbg.breakpoints[ key ] = state or 1
        print( "  ..breakpoint set." )
    end
end

function tinyldbg.rmbreakpoint( index )
    -- error check
    local idx = tonumber( index )
    if not idx then
        print( "  ..invalid index '" .. tostring(index) .. "'." )
        return
    end

    -- search for breakpoint
    local i = 1
    local key, val = next( tinyldbg.breakpoints )
    while val do
        if i == idx then
            tinyldbg.breakpoints[ key ] = nil
            print( "  ..breakpoint removed." )
            break
        end
        i = i + 1
        key, val = next( tinyldbg.breakpoints, key )
    end
    if not val then print( "  ..no breakpoint at index '" .. idx .. "'." ) end
end

function tinyldbg.togglebreakpoint( index, state )
    -- error check
    local idx = tonumber( index )
    if not idx then
        print( "  ..invalid index '" .. tostring(index) .. "'." ) return
    end
    local bstate = tonumber( state )
    if not bstate then
        print( "  ..invalid state '" .. tostring(state) .. "'." ) return
    end
    if bstate ~= 1 and bstate ~= 0 then bstate = 0 end

    -- search for breakpoint
    local i = 1
    local key, val = next( tinyldbg.breakpoints )
    while val do
        if i == idx then
            tinyldbg.breakpoints[ key ] = bstate
            print( "  ..breakpoint state changed." )
            break
        end
        i = i + 1
        key, val = next( tinyldbg.breakpoints, key )
    end
    if not val then print( "  ..no breakpoint at index '" .. idx .. "'." ) end
end

function tinyldbg.togglebreakpoints( state )
    -- error check
    local bstate = tonumber( state )
    if not bstate then
        print( "  ..invalid state '" .. tostring(state) .. "'." ) return
    end
    if bstate ~= 1 and bstate ~= 0 then bstate = 0 end

    -- change all breakpoints
    local key = next( tinyldbg.breakpoints )
    while key do
        tinyldbg.breakpoints[ key ] = bstate
        print( "  ..breakpoint state changed." )
        key = next( tinyldbg.breakpoints, key )
    end
end

function tinyldbg.listbreakpoints()
    local i = 1
    local t = { w = 0 }
    local key, val = next( tinyldbg.breakpoints )
    while val do
        t[i] = { n = key, v = tostring(val) }
        if string.len(key) > t.w then t.w = string.len(key) end
        i = i + 1
        key, val = next( tinyldbg.breakpoints, key )
    end
    tinyldbg.printtupletable( t )
end

function tinyldbg.clearbreakpoints()
    tinyldbg.breakpoints = {}
    print( "  ..breakpoints cleared." )
end

function tinyldbg.executelua( statement )
    -- first source the lua script
    local f, msg = loadstring( statement )
    if not f then print( msg )
    else
        -- then set function environment to that of broken line, and execute
        setfenv( f, getfenv( debug.getinfo(4).func ) )
        local success, msg = xpcall( f, function(...) return(unpack(arg)) end )
        if success then
            print( "  ..statement executed successfully." )
        else
            print( "  ..ERROR: " .. msg )
        end
    end
end

function tinyldbg.commandline( file, line )
    while true do
        print( "[ " .. file .. " - " .. line .. " ]:" )

        -- retrieve user input & parse arguments
        local buffer = io.stdin:read( "*l" )
        local args   = {}
        if not buffer then return end
        for x in string.gfind( buffer, "%S+" ) do table.insert( args, x ) end

        -- process
        if args[1] == "start" then
            tinyldbg.start()
        elseif args[1] == "quit" then
            tinyldbg.quit()
            break
        elseif args[1] == "help" then
            tinyldbg.help()
        elseif args[1] == "run" then
            break
        elseif args[1] == "step" then
            args[2] = tonumber( args[2] )
            if args[2] == nil then tinyldbg.skiplines = 1
            else tinyldbg.skiplines = args[2] end
            break
        elseif args[1] == "over" then
            tinyldbg.funcindex = 0
            debug.sethook( tinyldbg.hookfunction, "cr" )
            break
        elseif args[1] == "loadb" then
            tinyldbg.loadbreakpoints( args[2] )
        elseif args[1] == "saveb" then
            tinyldbg.savebreakpoints( args[2] )
        elseif args[1] == "listb" then
            tinyldbg.listbreakpoints()
        elseif args[1] == "setb" then
            tinyldbg.setbreakpoint( args[2], args[3] )
        elseif args[1] == "rmb" then
            tinyldbg.rmbreakpoint( args[2] )
        elseif args[1] == "onb" then
            tinyldbg.togglebreakpoint( args[2], 1 )
        elseif args[1] == "offb" then
            tinyldbg.togglebreakpoint( args[2], 0 )
        elseif args[1] == "allb" then
            tinyldbg.togglebreakpoints( args[2] )
        elseif args[1] == "clearb" then
            tinyldbg.clearbreakpoints()
        elseif args[1] == "locals" then
            tinyldbg.dumplocals()
        elseif args[1] == "upvals" then
            tinyldbg.dumpupvals()
        elseif args[1] == "globals" then
            tinyldbg.dumpglobals()
        elseif args[1] == "fenv" then
            tinyldbg.dumpfenv()
        elseif args[1] == "finfo" then
            tinyldbg.dumpfunctioninfo( args[2] )
        elseif args[1] == "trace" then
            print( debug.traceback() )
        elseif args[1] == "get" then
            tinyldbg.dumpvariable( args[2] )
        elseif args[1] == "set" then
            tinyldbg.setvariable( args[2], args[3], 3 )
        elseif args[1] == "seti" then
            tinyldbg.setvariable( args[2], tonumber(args[3]), 3 )
        elseif args[1] == "lua" then
            tinyldbg.executelua( string.sub( buffer, 5, -1 ) )
        elseif args[1] == "bind" then
            tinyldbg.bindvariable( args[2], args[3] )
        end
    end
end

function tinyldbg.hookfunction( event, line )
    if event == "call" then
        tinyldbg.funcindex = tinyldbg.funcindex + 1
    else
        tinyldbg.funcindex = tinyldbg.funcindex - 1
        if tinyldbg.funcindex == 0 then
            debug.sethook( tinyldbg.hookline, "l" )
        end
    end
end

function tinyldbg.hookline( event, line )
    if not tinyldbg then return end
    if not tinyldbg.breakpoints then return end

    -- retrieve filename where line defined, modify & generate hash key
    local fnamelong = debug.getinfo(2).source
    local key = tinyldbg.safehash( fnamelong, line )

    -- check for line increment
    if tinyldbg.skiplines > 0 then
        print( "." )
        tinyldbg.skiplines = tinyldbg.skiplines - 1
        if tinyldbg.skiplines == 0 then
            tinyldbg.commandline( fnamelong, line )
        end
    -- check for stepping over a function
    elseif tinyldbg.funcindex == 0 then
        tinyldbg.funcindex = -1
        tinyldbg.commandline( fnamelong, line )
    -- check if line is a breakpoint
    elseif tinyldbg.breakpoints[ key ] == 1 then
        tinyldbg.commandline( fnamelong, line )
    end
end


--=====================================
-- UTILITY STUFF
--=====================================

-- get short filename
--local i,j   = string.find( s, "([%w_%-]*%.lua)$" )
--local fname = string.sub( s, i, j )
