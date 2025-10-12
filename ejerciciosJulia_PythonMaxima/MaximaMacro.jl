module MaximaMacro

"""
Macro @evaluarMaxima "comando"
Ejecuta el comando en Maxima y devuelve la salida como cadena limpia.
"""
macro evaluarMaxima(cmd_str)
    cmd = String(cmd_str)  # convierte la cadena literal en texto
    return quote
        # Asegura que termina con símbolo de fin de comando ($ o ;)
        #cmd = endswith($cmd, "$") || endswith($cmd, ";") ? $cmd : $cmd * "$"
        output = read(`maxima --very-quiet --batch-string="$_cmd"`, String)
        # Limpieza básica
        lines = split(output, '\n')
        cleaned = filter(l -> !isempty(strip(l)) && !occursin("batch", l) && !occursin("Entering", l), lines)
        join(cleaned, "\n")
    end
end

end # module
