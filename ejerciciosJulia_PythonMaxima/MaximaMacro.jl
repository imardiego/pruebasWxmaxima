# maximaMacro.jl
# Macros para ejecutar Maxima desde Julia
"""
# Macro simple para ejecutar un único comando Maxima
@maxima comando
Devolverá la salida de un único comando Maxima.

# Ejemplo 1: Derivada
@maxima diff(x^2 + sin(x), x)

# Ejemplo 2: Integral
@maxima integrate(x^2, x)

# Ejemplo 3: Simplificación
@maxima ratsimp((x^2 - 1)/(x - 1))

@maxima integrate(exp(-x^2),x)


Devolverá la salida de cada comando Maxima.

diff(x^2+sin(x),x)
                                 cos(x) + 2 x


integrate(x^2,x)
                                       3
                                      x
                                      --
                                      3


ratsimp((x^2-1)/(x-1))
                                     x + 1


integrate(exp(-x^2),x)
                               sqrt(%pi) erf(x)
                               ----------------
                                      2


#############################################################

@maxima_cell begin
    expand((x + 1)^3);
    diff(sin(x)^2, x);
    integrate(exp(-x^2), x);
    H : 1/sqrt(2) * matrix([1, 1], [1, -1]); 
    I : ident(2);
end

Devolverá la salida de varios comandos Maxima en bloque.
# Ejemplo de uso de @maxima_cell

💡 Comando: expand((x + 1) ^ 3)

💡 Respuesta maxima:
expand((x+1)^3)
                               3      2
                              x  + 3 x  + 3 x + 1


💡 Comando: diff(sin(x) ^ 2, x)

💡 Respuesta maxima:
diff(sin(x)^2,x)
                                2 cos(x) sin(x)


💡 Comando: integrate(exp(-(x ^ 2)), x)

💡 Respuesta maxima:
integrate(exp(-x^2),x)
                               sqrt(%pi) erf(x)
                               ----------------
                                      2


💡 Comando: H:(1 / sqrt(2)) * matrix([1, 1], [1, -1])

💡 Respuesta maxima:
H:(1/sqrt(2))*matrix([1,1],[1,-1])
                            [    1         1     ]
                            [ -------   -------  ]
                            [ sqrt(2)   sqrt(2)  ]
                            [                    ]
                            [    1          1    ]
                            [ -------  - ------- ]
                            [ sqrt(2)    sqrt(2) ]


💡 Comando: I:ident(2)

💡 Respuesta maxima:
I:ident(2)
                                   [ 1  0 ]
                                   [      ]
                                   [ 0  1 ]


"""

# Macro simple para ejecutar un único comando Maxima
macro maxima(expr)
    cmd = string(expr)
    println(read(`maxima --very-quiet --batch-string="$cmd;"`, String))
end



# Macro para ejecutar varios comandos Maxima en bloque
macro maxima_cell(ex)
    # Construimos la lista de comandos (cada stmt por separado)
    cmds = String[]
    if ex isa Expr && ex.head == :block
        for stmt in ex.args
            s = string(stmt)                    # crea "expand((x+1)^3)" (sin :(...))
            s = replace(s, r"#=.*=#" => "")    # limpia anotaciones de IJulia
            s = strip(s)
            # eliminar un posible ';' final (si se escribió)
            if endswith(s, ";")
                s = rstrip(s, ';')
                s = strip(s)
            end
            if !isempty(s)
                push!(cmds, s)
            end
        end
    else
        s = string(ex)
        s = replace(s, r"#=.*=#" => "")
        s = strip(s)
        if endswith(s, ";")
            s = rstrip(s, ';')
            s = strip(s)
        end
        if !isempty(s)
            push!(cmds, s)
        end
    end

    # Ejecutamos cada comando por separado en Maxima y acumulamos salidas
    results_buf = IOBuffer()
    outputs = String[]
    for cmd in cmds
        try
            out = read(`maxima --very-quiet --batch-string="$cmd;"`, String)
            println(results_buf, "\n💡 Comando: ", cmd)
            println(results_buf, "\n💡 Respuesta maxima:", out)
            push!(outputs, out)
        catch e
            println(results_buf, "\n⚠️ Error ejecutando '$cmd': $e")
            push!(outputs, "ERROR: $e")
        end
    end

    # Imprimimos la salida acumulada y devolvemos la lista de resultados
    printed = String(take!(results_buf))
    return :(begin
        print($printed)
        $(outputs)
    end)
end





