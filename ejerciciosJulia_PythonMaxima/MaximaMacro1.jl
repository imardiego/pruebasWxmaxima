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
    cmd = replace(string(expr), "\"" => "\\\"")
    print("💡",read(`maxima --very-quiet --batch-string="$cmd;"`, String))
end



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






