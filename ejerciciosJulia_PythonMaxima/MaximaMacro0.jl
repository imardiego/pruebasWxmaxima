module MaximaMacro

export @maxima, @maxima_cell, @maxima_session

"""
@maxima expr

Ejecuta un único comando de Maxima y muestra su salida.

# Ejemplo

@maxima diff(x^2 + sin(x), x)

"""


# Macro simple para ejecutar un único comando Maxima
macro maxima(expr)
    cmd = replace(string(expr), "\"" => "\\\"")
    print("💡",read(`maxima --very-quiet --batch-string="$cmd;"`, String))
end

"""
@maxima_cell begin
expand((x + 1)^3)
diff(sin(x)^2, x)
end

Ejecuta varios comandos de Maxima, cada uno en su propia instancia.
Ideal para ejemplos independientes.
"""

macro maxima_cell(ex)
    cmds = String[]
    if ex isa Expr && ex.head === :block
        for stmt in ex.args
            s = replace(string(stmt), r"#=.*?=#" => "") |> strip
            s = replace(s, r";+$" => "") |> strip
            !isempty(s) && push!(cmds, s)
        end
    else
        s = replace(string(ex), r"#=.*?=#" => "") |> strip
        s = replace(s, r";+$" => "") |> strip
        !isempty(s) && push!(cmds, s)
    end
    for cmd in cmds
        escaped = replace(cmd, "\"" => "\\\"")
        out = read(`maxima --very-quiet --batch-string="$escaped;"`, String)
        #println("\n💡 Comando: ", cmd)
        #println("💡 Respuesta Maxima:")
        println("💡",out)
        #print(out)
    end
end

"""
@maxima_session begin
x = 1
y = x^2
z = x + y
z
end

Ejecuta un bloque de comandos en una única sesión de Maxima (estado persistente).

Usa = para asignación (se convierte a : de Maxima).
Funciona con Maxima+GCL (usa --batch-string, sin archivos temporales).
Ideal para cálculos con variables, matrices, librerías como qinf, etc.
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
                        cmd_str = "$(lhs):$(rhs)"
                    end
                catch
                end
            else
                s = string(stmt)
                s = replace(s, r"#=.+?=#" => "")
                s = replace(s, r";+$" => "")
                s = replace(s, r"\s+" => "")
                if !isempty(s)
                    cmd_str = s
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

    # ✅ Último comando con ;, los demás con $
    n = length(cmds)
    for i in 1:n
        if i == n
            cmds[i] *= ";"
        else
            cmds[i] *= "\$"
        end
    end

    full_cmd = join(cmds, "")
    output = read(`maxima --very-quiet --batch-string="$full_cmd"`, String)
    
    # ✅ Extraer solo la parte del resultado (última línea no vacía útil)
    lines = [strip(l) for l in split(output, '\n') if !isempty(strip(l))]
    if !isempty(lines)
        # Tomar la última línea que parece un resultado
        result = lines[end]
        # Eliminar prefijo como (%o4) si existe
        result = replace(result, r"^\s*$$%[io]\d+$$\s*" => "")
        println(result)
    end
    return nothing
end

end # module


