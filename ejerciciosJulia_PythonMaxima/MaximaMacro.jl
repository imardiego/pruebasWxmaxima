module MaximaMacro

export @maxima, @maxima_cell, @maxima_session, maxima_eval, maxima_eval_float

# Variables de entorno para GCL (según Camm Maguire, GCL developer)
# Fuente: https://lists.gnu.org/archive/html/gcl-devel/2017-09/msg00000.html
const _GCL_ENV = Dict(
    "GCL_MEM_MULTIPLE" => "0.3",     # Usa solo el 30% de la RAM física
    "GCL_GC_PAGE_THRESH" => "0.2",   # Inicia GC más temprano
    "GCL_GC_ALLOC_MIN" => "0.01",    # Mínima asignación entre GCs
    "GCL_GC_PAGE_MAX" => "0.5"       # Fuerza GC antes de llegar al 50% del heap
)


"""
    maxima_eval(cmd::String)

Ejecuta un comando de Maxima y devuelve el resultado como `String`.

# Ejemplo

maxima_eval("diff(x^2, x)")  # → "2*x"
maxima_eval("x:3; x^2+1")  # → "9"

"""


function maxima_eval(cmd::String)
    cmd = strip(cmd)
    if !endswith(cmd, ";")
        cmd *= ";"
    end
        cmd *= "\n" # Evita "Premature termination" en GCL
    safe_cmd = replace(cmd, "\"" => "\\\"")
    env = copy(ENV)
    merge!(env, _GCL_ENV)
    raw_output = read(setenv(`maxima --very-quiet --batch-string="$safe_cmd;"`, env), String)
    
    # ✅ Eliminar caracteres no imprimibles (nulos, controles)
    clean_output = filter(c -> c >= ' ' && c <= '~' || c == '\n' || c == '\r', raw_output)
    
    lines = [strip(l) for l in split(clean_output, '\n') if !isempty(strip(l))]
    
    # ✅ Buscar la última línea que sea un número o expresión (no comando)
    for i in length(lines):-1:1
        l = lines[i]
        # Si contiene :, es un comando (x:4)
        # Si empieza con (, es un prompt (%o1)
        if !contains(l, ":") && !startswith(l, "(") && !startswith(l, "incorrect syntax") && 
           !startswith(l, "batch(") && l != ";" && l != "^"
           return l
        end
    end
    return ""
end

"""
    maxima_eval_float(cmd::String)

Ejecuta un comando de Maxima y devuelve el resultado como Float64 si es numérico.
Si no es numérico, devuelve el resultado como String.

# Ejemplo
maxima_eval_float("float(22/7)")      # → 3.142857142857143
maxima_eval_float("sqrt(2)")          # → "sqrt(2)" (no es numérico sin float())
maxima_eval_float("float(sqrt(2))")   # → 1.4142135623730951"

"""

function maxima_eval_float(cmd::String)
    res = maxima_eval(cmd)
    if res == ""
        return res
    end

    try
    # Intentar convertir a número
        return parse(Float64, res)
    catch
    # Si falla, devolver el string original
        return res
    end
end

"""
@maxima expr

Ejecuta un único comando de Maxima.
"""
macro maxima(expr)
    cmd_str=string(expr)
    escaped_cmd = replace(cmd_str, "\"" => "\\\"")
    out=read(`maxima --very-quiet --batch-string="$escaped_cmd;"`, String)
    #println("DEBUG: Salida = ", repr(out[2:end])) # Depuración
    out=out[2:end] # Eliminar el primer carácter de nueva línea
    print("💡 ", out)
end

"""
@maxima_cell begin ... end

Ejecuta varios comandos, cada uno en su propia instancia.
"""
macro maxima_cell(ex)
    cmds = String[]
    if ex isa Expr && ex.head === :block
        for stmt in ex.args
            s = replace(string(stmt), r"#=.+?=#" => "") |> strip
            s = replace(s, r";+$" => "") |> strip
            !isempty(s) && push!(cmds, s)
        end
    else
        s = replace(string(ex), r"#=.+?=#" => "") |> strip
        s = replace(s, r";+$" => "") |> strip
        !isempty(s) && push!(cmds, s)
    end
    for cmd in cmds
        escaped = replace(cmd, "\"" => "\\\"")
        out = read(`maxima --very-quiet --batch-string="$escaped;"`, String)
        out=(out[2:end]) # Eliminar el primer carácter de nueva línea
        println("💡 ", out)
    end
end

"""
@maxima_session begin ... end

Ejecuta un bloque en una única sesión (estado persistente).
"""
macro maxima_session(ex)
    cmds = String[]
    if ex isa Expr && ex.head === :block
        for stmt in ex.args
            cmd_str = ""
            if stmt isa Expr && stmt.head === :(=)
                try
                    lhs = string(stmt.args[1])
                    rhs = string(stmt.args[2])
                    lhs = replace(lhs, r"\s+" => "")
                    rhs = replace(rhs, r"\s+" => "")
                    if !isempty(lhs) && !isempty(rhs)
                        cmd_str = "$(lhs):$(rhs);"
                    end
                catch
                end
            else
                s = string(stmt)
                s = replace(s, r"#=.+?=#" => "")
                s = replace(s, r";+$" => "")
                s = replace(s, r"\s+" => "")
                if !isempty(s)
                    cmd_str = s * ";"
                end
            end
            if !isempty(cmd_str)
                push!(cmds, cmd_str)
            end
        end
    else
        return :(nothing)
    end

    if isempty(cmds)
        return :(nothing)
    end

    full_cmd = join(cmds, " ")
    escaped_cmd = replace(full_cmd, "\"" => "\\\"")
    
    # Depuración
    #println("DEBUG: Comando = ", repr(full_cmd))
    
    output = read(`maxima --very-quiet --batch-string="$escaped_cmd"`, String)
    #println("DEBUG: Salida = ", repr(output))
    
    # Extraer el último resultado numérico o simbólico
    lines = [strip(l) for l in split(output, '\n') if !isempty(strip(l))]
    # Tomar la última línea que NO es un comando (no contiene :)
    for i in length(lines):-1:1
        if !contains(lines[i], ":") && !startswith(lines[i], "(")
            println("💡 ",lines[i])
            return nothing
        end
    end
    if !isempty(lines)
        println(lines[end])
    end
    return nothing
end

end # module MaximaMacro