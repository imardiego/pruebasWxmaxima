# ------------------------------------------------------------
# Módulo MaximaMacro.jl
# Interfaz avanzada entre Julia y Maxima para entornos como Jupyter
# Permite ejecutar comandos de Maxima con sesión persistente,
# salida limpia, gráficos integrados y opciones de exportación.
# ------------------------------------------------------------

module MaximaMacro

# Dependencias del módulo estándar de Julia
using Base: tempname      # Genera nombres de archivos temporales únicos
using Dates               # Para marcar fecha/hora en los nombres de gráficos
import Base.display       # Permitir mostrar gráficos en Jupyter

# Exportar las funciones/macro que el usuario podrá usar
export @maxima_cell_session, @maxima, maxima_eval

# ------------------------------------------------------------
# Macro simple: @maxima
# Ejecuta un solo comando de Maxima y muestra la salida cruda.
# Útil para pruebas rápidas.
# ------------------------------------------------------------
macro maxima(expr)
    # Convertir la expresión a cadena y escapar comillas
    cmd = replace(string(expr), "\"" => "\\\"")
    # Ejecutar Maxima en modo muy silencioso y mostrar resultado
    print(read(`maxima --very-quiet --batch-string="$cmd;"`, String))
end

# ------------------------------------------------------------
# Función: maxima_eval
# Evalúa un único comando de Maxima y devuelve solo el resultado (como cadena).
# Útil para uso programático (no desde la macro principal).
# ------------------------------------------------------------
function maxima_eval(cmd::String)::String
    stripped = strip(cmd)
    # Asegurar que el comando termine en ; o $
    if !endswith(stripped, ";") && !endswith(stripped, "\$")
        cmd = cmd * ";"
    end

    # Abrir proceso de Maxima en modo interactivo (pero sin salida de inicio)
    proc = open(`maxima --quiet`, "r+")
    # Configurar entorno: salida 1D, líneas largas, cargar qinf si existe
    write(proc.in, "display2d:false\$\n")
    write(proc.in, "linel:32767\$\n")
    write(proc.in, "ignore(load(\"qinf\"))\$\n")  # No fallar si no existe
    write(proc.in, cmd * "\n")
    close(proc.in)  # Cerrar entrada para que Maxima termine
    raw = String(read(proc.out))  # Leer toda la salida
    wait(proc)  # Esperar a que el proceso termine

    # Buscar la línea (%o4) que contiene el resultado del cuarto comando
    # (los tres primeros son configuración)
    for line in split(raw, '\n')
        s = strip(line)
        m = match(r"^\s*\(%o4\)\s*(.+)", s)
        if m !== nothing
            return m.captures[1]
        end
    end
    return ""
end

# ------------------------------------------------------------
# Función auxiliar: is_plot_command
# Detecta si un comando es gráfico (plot2d, plot3d, etc.)
# ------------------------------------------------------------
function is_plot_command(cmd::String)::Bool
    lower = lowercase(cmd)
    # Lista de palabras clave que indican un comando gráfico
    return any(kw -> occursin(kw, lower), ["plot2d", "plot3d", "draw2d", "draw3d", "wxplot"])
end

# ------------------------------------------------------------
# Macro principal: @maxima_cell_session
# Permite ejecutar múltiples comandos en una sola sesión de Maxima,
# manteniendo el estado entre ellos (variables, funciones, etc.).
# Soporta gráficos, créditos reales y guardado en fichero.
# ------------------------------------------------------------
macro maxima_cell_session(exs...)
    if length(exs) == 0
        error("Se requiere al menos un comando Maxima")
    end

    # Variables para opciones opcionales
    creditos = false   # ¿Mostrar créditos de Maxima?
    fichero = nothing  # ¿Guardar salida en un fichero de texto?
    cmds_list = Any[exs...]  # Lista de argumentos

    # --------------------------------------------------------
    # Detectar si el último argumento es creditos=true
    # --------------------------------------------------------
    if length(cmds_list) >= 1
        last_arg = cmds_list[end]
        if last_arg isa Expr && last_arg.head === :(=) &&
           length(last_arg.args) == 2 &&
           last_arg.args[1] == :creditos &&
           last_arg.args[2] == true
            creditos = true
            pop!(cmds_list)  # Eliminar de la lista de comandos
        end
    end

    # --------------------------------------------------------
    # Detectar si el último argumento es fichero="nombre.txt"
    # --------------------------------------------------------
    if length(cmds_list) >= 1
        last_arg = cmds_list[end]
        if last_arg isa Expr && last_arg.head === :(=) &&
           length(last_arg.args) == 2 &&
           last_arg.args[1] == :fichero
            val = last_arg.args[2]
            if val isa String
                fichero = val
            elseif val isa Expr && val.head === :string
                # Extraer cadena de una expresión de cadena
                str_repr = sprint(show, val)
                if length(str_repr) >= 2 && str_repr[1] == '"' && str_repr[end] == '"'
                    fichero = str_repr[2:end-1]
                else
                    error("Nombre de fichero no válido")
                end
            else
                error("El argumento 'fichero' debe ser una cadena")
            end
            pop!(cmds_list)  # Eliminar de la lista de comandos
        end
    end

    # --------------------------------------------------------
    # Validar y preparar los comandos del usuario
    # --------------------------------------------------------
    user_cmds = String[]
    for ex in cmds_list
        if ex isa String
            cmd = ex
        elseif ex isa Expr && ex.head === :string
            # Convertir expresión de cadena a cadena real
            str_repr = sprint(show, ex)
            if length(str_repr) >= 2 && str_repr[1] == '"' && str_repr[end] == '"'
                cmd = str_repr[2:end-1]
            else
                error("Cadena no válida: $ex")
            end
        else
            error("Solo se permiten cadenas literales entre comillas")
        end

        # Asegurar que cada comando termine en ; o $
        stripped = strip(cmd)
        if !endswith(stripped, ";") && !endswith(stripped, "\$")
            cmd = cmd * ";"
        end
        push!(user_cmds, cmd)
    end

    # --------------------------------------------------------
    # ¿Hay algún comando gráfico?
    # --------------------------------------------------------
    has_plot = any(cmd -> is_plot_command(cmd), user_cmds)

    # --------------------------------------------------------
    # Modo con gráficos: procesar todos los comandos en una sola sesión
    # --------------------------------------------------------
    if has_plot
        quote
            # ----------------------------------------------------
            # Mostrar aviso si se piden créditos (no compatibles con gráficos)
            # ----------------------------------------------------
            if $(creditos)
                println("ℹ️  El modo 'creditos=true' se ignora cuando hay gráficos.")
            end

            cmds = $(user_cmds)
            processed_cmds = String[]  # Comandos adaptados para Maxima

            # ----------------------------------------------------
            # Preprocesar comandos: convertir plot2d en versión con salida a archivo
            # ----------------------------------------------------
            for (i, cmd) in enumerate(cmds)
                if $(is_plot_command)(cmd)
                    cmd_clean = strip(replace(cmd, r"[;\$]$" => ""))
                    tmpfile = joinpath(pwd(), "maxima_plot_temp_$(i).png")
                    # Añadir opciones de Gnuplot directamente en el comando
                    if endswith(cmd_clean, ")")
                        new_cmd = cmd_clean[1:end-1] *
                                  ", [gnuplot_term, png], " *
                                  "[gnuplot_out_file, \"$(tmpfile)\"])"
                    else
                        new_cmd = cmd_clean
                    end
                    push!(processed_cmds, new_cmd * ";")
                else
                    push!(processed_cmds, cmd)
                end
            end

            # ----------------------------------------------------
            # Ejecutar todos los comandos en una sola sesión de Maxima
            # ----------------------------------------------------
            proc = open(`maxima --quiet`, "r+")
            write(proc.in, "display2d:false\$\n")
            write(proc.in, "linel:32767\$\n")
            write(proc.in, "ignore(load(\"qinf\"))\$\n")
            write(proc.in, "gnuplot_pipes: true\$\n")  # Necesario para gráficos en batch
            for cmd in processed_cmds
                write(proc.in, cmd * "\n")
            end
            close(proc.in)
            raw_output = String(read(proc.out))
            wait(proc)

            # ----------------------------------------------------
            # Extraer resultados no gráficos (%oN)
            # ----------------------------------------------------
            results = Dict{Int, String}()
            for line in split(raw_output, '\n')
                s = strip(line)
                m = match(r"^\s*\(%o(\d+)\)\s*(.*)", s)
                if m !== nothing
                    n = parse(Int, m.captures[1])
                    results[n] = m.captures[2]
                end
            end

            # ----------------------------------------------------
            # Mostrar salida en tiempo real (para mantener orden en Jupyter)
            # y preparar contenido para fichero
            # ----------------------------------------------------
            output_lines = String[]

            for (i, cmd) in enumerate(cmds)
                cmd_clean = rstrip(strip(cmd), [';', '\$'])
                terminator = endswith(strip(cmd), "\$") ? "\$" : ";"
                line_i = "(%i$(i)) $(cmd_clean)$(terminator)"
                println(line_i)
                push!(output_lines, line_i)

                if $(is_plot_command)(cmd)
                    # Mostrar línea de salida para gráfico
                    line_o = "(%o$(i)) gráfico:"
                    println(line_o)
                    println()
                    push!(output_lines, line_o)
                    push!(output_lines, "")

                    # ------------------------------------------------
                    # Mostrar gráfico en Jupyter y guardar copia
                    # ------------------------------------------------
                    tmpfile = joinpath(pwd(), "maxima_plot_temp_$(i).png")
                    permanent_path = ""
                    if isfile(tmpfile) && filesize(tmpfile) > 0
                        img_data = read(tmpfile)
                        display(MIME("image/png"), img_data)  # ← AQUÍ se muestra en su sitio
                        plot_dir = joinpath(pwd(), "plots")
                        mkpath(plot_dir)
                        timestamp = replace(string(now()), r"[:\.\- ]" => "_")
                        permanent_path = joinpath(plot_dir, "plot_$(timestamp)_$(i).png")
                        write(permanent_path, img_data)
                        isfile(tmpfile) && rm(tmpfile, force=true)
                    end

                    # Añadir ruta al fichero de salida (solo si se pide)
                    if $(fichero !== nothing) && permanent_path != ""
                        rel_path = replace(permanent_path, pwd() * "/" => "./")
                        path_line = "→ Guardado en: $(rel_path)"
                        push!(output_lines, path_line)
                    end
                else
                    # Mostrar resultado no gráfico
                    result_key = i + 4  # 4 comandos de inicialización
                    if haskey(results, result_key)
                        res_line = "(%o$(i)) $(results[result_key])"
                        println(res_line)
                        push!(output_lines, res_line)
                    end
                    println()
                    push!(output_lines, "")
                end
            end

            # ----------------------------------------------------
            # Guardar toda la salida en un fichero de texto (si se pide)
            # ----------------------------------------------------
            if $(fichero !== nothing)
                output_text = join(output_lines, "\n") * "\n"
                write($(Meta.quot(fichero)), output_text)
            end
            nothing
        end
    else
        # --------------------------------------------------------
        # Modo sin gráficos: similar, pero más simple
        # --------------------------------------------------------
        quote
            cmds = $(user_cmds)
            output_lines = String[]

            # ----------------------------------------------------
            # Mostrar créditos reales de Maxima si se piden
            # ----------------------------------------------------
            if $(creditos)
                proc_credit = open(`maxima --batch-string="quit();"`, "r")
                credit_lines = String(read(proc_credit.out))
                wait(proc_credit)

                printed = false
                for line in split(credit_lines, '\n')
                    s = rstrip(line)
                    # Detenerse al encontrar la primera línea de entrada (%i1)
                    if occursin(r"%i\d+", s)
                        break
                    end
                    if !printed && s == ""
                        continue
                    end
                    println(s)
                    push!(output_lines, s)
                    printed = true
                end
                println()
                push!(output_lines, "")
            end

            # ----------------------------------------------------
            # Ejecutar comandos en una sola sesión
            # ----------------------------------------------------
            proc = open(`maxima --quiet`, "r+")
            write(proc.in, "display2d:false\$\n")
            write(proc.in, "linel:32767\$\n")
            write(proc.in, "ignore(load(\"qinf\"))\$\n")
            for cmd in cmds
                write(proc.in, cmd * "\n")
            end
            close(proc.in)
            raw_output = String(read(proc.out))
            wait(proc)

            # Extraer resultados
            results = Dict{Int, String}()
            for line in split(raw_output, '\n')
                s = strip(line)
                m = match(r"^\s*\(%o(\d+)\)\s*(.*)", s)
                if m !== nothing
                    n = parse(Int, m.captures[1])
                    results[n] = m.captures[2]
                end
            end

            # Mostrar salida
            for (i, cmd) in enumerate(cmds)
                cmd_clean = rstrip(strip(cmd), [';', '\$'])
                terminator = endswith(strip(cmd), "\$") ? "\$" : ";"
                line_i = "(%i$(i)) $(cmd_clean)$(terminator)"
                println(line_i)
                push!(output_lines, line_i)

                result_key = i + 3  # 3 comandos de inicialización
                if haskey(results, result_key)
                    res_line = "(%o$(i)) $(results[result_key])"
                    println(res_line)
                    push!(output_lines, res_line)
                end
                println()
                push!(output_lines, "")
            end

            # Guardar en fichero si se pide
            if $(fichero !== nothing)
                output_text = join(output_lines, "\n") * "\n"
                write($(Meta.quot(fichero)), output_text)
            end
            nothing
        end
    end
end

end  # module MaximaMacro