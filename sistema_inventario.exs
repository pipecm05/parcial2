defmodule SistemaInventario do
  defmodule Pieza do
    defstruct codigo: "", nombre: "", valor: 0, unidad: "", stock: 0
  end

  defmodule Movimiento do
    defstruct codigo: "", tipo: "", cantidad: 0, fecha: ""
  end


  def iniciar_sistema() do
    IO.puts("SISTEMA DE GESTIÓN DE INVENTARIO")
    IO.puts("====================================")
    cargar_archivos()
    menu_principal()
  end

  defp cargar_archivos() do
    # Crear archivos si no existen
    unless File.exists?("piezas.csv") do
      File.write!("piezas.csv", "")
      IO.puts(" Archivo piezas.csv creado")
    end

    unless File.exists?("movimientos.csv") do
      File.write!("movimientos.csv", "")
      IO.puts(" Archivo movimientos.csv creado")
    end

    unless File.exists?("inventario_actual.csv") do
      File.write!("inventario_actual.csv", "")
    end
  end

  defp menu_principal() do
    IO.puts("\n MENÚ PRINCIPAL")
    IO.puts("1.  Ver inventario actual")
    IO.puts("2.  Agregar nueva pieza")
    IO.puts("3.  Realizar movimiento (ENTRADA/SALIDA)")
    IO.puts("4.  Consultar piezas con stock bajo")
    IO.puts("5.  Ver movimientos por rango de fechas")
    IO.puts("6.  Eliminar piezas duplicadas")
    IO.puts("7.  Guardar y salir")

    case IO.gets("Seleccione una opción: ") |> String.trim() do
      "1" -> ver_inventario()
      "2" -> agregar_pieza()
      "3" -> realizar_movimiento()
      "4" -> consultar_stock_bajo()
      "5" -> movimientos_por_fecha()
      "6" -> eliminar_duplicados_menu()
      "7" -> guardar_y_salir()
      _ ->
        IO.puts(" Opción inválida")
        menu_principal()
    end
  end

  defp ver_inventario() do
    IO.puts("\n INVENTARIO ACTUAL")
    IO.puts("===================")

    case leer_piezas("inventario_actual.csv") do
      {:ok, []} ->
        IO.puts("El inventario está vacío")
        case leer_piezas("piezas.csv") do
          {:ok, piezas} when piezas != [] ->
            IO.puts("Cargando desde piezas.csv...")
            mostrar_piezas(piezas)
          _ ->
            IO.puts("No hay piezas en el sistema")
        end

      {:ok, piezas} ->
        mostrar_piezas(piezas)

      {:error, razon} ->
        IO.puts(" Error: #{razon}")
    end

    menu_principal()
  end

  defp mostrar_piezas(piezas) do
    IO.puts("┌──────────┬──────────────────┬────────┬────────┬───────┐")
    IO.puts("│ Código   │ Nombre           │ Valor  │ Unidad │ Stock │")
    IO.puts("├──────────┼──────────────────┼────────┼────────┼───────┤")

    Enum.each(piezas, fn p ->
      :io.format("│ ~-8s │ ~-16s │ ~-6s │ ~-6s │ ~-5s │~n",
                [p.codigo, p.nombre, to_string(p.valor), p.unidad, to_string(p.stock)])
    end)

    IO.puts("└──────────┴──────────────────┴────────┴────────┴───────┘")
    IO.puts("Total de piezas: #{length(piezas)}")
  end

  defp agregar_pieza() do
    IO.puts("\n AGREGAR NUEVA PIEZA")
    IO.puts("====================")

    codigo = IO.gets("Código: ") |> String.trim()
    nombre = IO.gets("Nombre: ") |> String.trim()

    valor_input = IO.gets("Valor: ") |> String.trim()
    valor = case Integer.parse(valor_input) do
      {v, ""} -> v
      _ ->
        IO.puts(" Valor inválido")
        menu_principal()
        return_nothing()
    end

    unidad = IO.gets("Unidad (ohm, uF, V, etc): ") |> String.trim()

    stock_input = IO.gets("Stock inicial: ") |> String.trim()
    stock = case Integer.parse(stock_input) do
      {s, ""} -> s
      _ ->
        IO.puts("Stock inválido")
        menu_principal()
        return_nothing()
    end

    nueva_pieza = %Pieza{
      codigo: codigo,
      nombre: nombre,
      valor: valor,
      unidad: unidad,
      stock: stock
    }

    case leer_piezas("piezas.csv") do
      {:ok, piezas_existentes} ->
        # Verificar si el código ya existe
        if Enum.any?(piezas_existentes, fn p -> p.codigo == codigo end) do
          IO.puts(" Ya existe una pieza con ese código")
        else
          todas_las_piezas = [nueva_pieza | piezas_existentes]
          guardar_piezas(todas_las_piezas, "piezas.csv")
          IO.puts(" Pieza agregada exitosamente")
        end

      {:error, _} ->
        guardar_piezas([nueva_pieza], "piezas.csv")
        IO.puts(" Pieza agregada exitosamente")
    end

    menu_principal()
  end

  defp return_nothing(), do: nil

  defp realizar_movimiento() do
    IO.puts("\n REALIZAR MOVIMIENTO")
    IO.puts("====================")

    codigo = IO.gets("Código de pieza: ") |> String.trim()

    tipo_input = IO.gets("Tipo (ENTRADA/SALIDA): ") |> String.trim() |> String.upcase()

    unless tipo_input in ["ENTRADA", "SALIDA"] do
      IO.puts(" Tipo debe ser ENTRADA o SALIDA")
      menu_principal()
      return_nothing()
    end

    cantidad_input = IO.gets("Cantidad: ") |> String.trim()
    cantidad = case Integer.parse(cantidad_input) do
      {c, ""} when c > 0 -> c
      _ ->
        IO.puts(" Cantidad inválida")
        menu_principal()
        return_nothing()
    end

    fecha = IO.gets("Fecha (YYYY-MM-DD): ") |> String.trim()

    # Validar formato de fecha simple
    unless String.match?(fecha, ~r/^\d{4}-\d{2}-\d{2}$/) do
      IO.puts(" Formato de fecha inválido. Use YYYY-MM-DD")
      menu_principal()
      return_nothing()
    end

    nuevo_movimiento = %Movimiento{
      codigo: codigo,
      tipo: tipo_input,
      cantidad: cantidad,
      fecha: fecha
    }

    # Guardar movimiento
    case leer_movimientos("movimientos.csv") do
      {:ok, movimientos} ->
        guardar_movimientos([nuevo_movimiento | movimientos], "movimientos.csv")
      {:error, _} ->
        guardar_movimientos([nuevo_movimiento], "movimientos.csv")
    end

    IO.puts(" Movimiento registrado exitosamente")

    # Actualizar inventario
    actualizar_inventario()

    menu_principal()
  end

  defp consultar_stock_bajo() do
    IO.puts("\n CONSULTAR STOCK BAJO")
    IO.puts("======================")

    umbral_input = IO.gets("Umbral de stock bajo: ") |> String.trim()
    umbral = case Integer.parse(umbral_input) do
      {u, ""} when u > 0 -> u
      _ ->
        IO.puts(" Umbral inválido")
        menu_principal()
        return_nothing()
    end

    case leer_piezas("inventario_actual.csv") do
      {:ok, piezas} ->
        piezas_bajas = Enum.filter(piezas, fn p -> p.stock < umbral end)

        if piezas_bajas == [] do
          IO.puts(" No hay piezas con stock por debajo de #{umbral}")
        else
          IO.puts(" Piezas con stock bajo (#{umbral}):")
          mostrar_piezas(piezas_bajas)

          cantidad = contar_stock_bajo(piezas, umbral)
          IO.puts("Total de piezas con stock bajo: #{cantidad}")
        end

      {:error, razon} ->
        IO.puts(" Error: #{razon}")
    end

    menu_principal()
  end

  defp movimientos_por_fecha() do
    IO.puts("\n MOVIMIENTOS POR RANGO DE FECHAS")
    IO.puts("==================================")

    fecha_inicio = IO.gets("Fecha inicio (YYYY-MM-DD): ") |> String.trim()
    fecha_fin = IO.gets("Fecha fin (YYYY-MM-DD): ") |> String.trim()

    case leer_movimientos("movimientos.csv") do
      {:ok, movimientos} ->
        total = cantidad_movida_rango(movimientos, {fecha_inicio, fecha_fin})

        IO.puts("\n RESUMEN DE MOVIMIENTOS")
        IO.puts("Rango: #{fecha_inicio} a #{fecha_fin}")
        IO.puts("Total de unidades movidas: #{total}")

        # Mostrar movimientos en el rango
        movimientos_rango = Enum.filter(movimientos, fn m ->
          fecha_en_rango?(m.fecha, fecha_inicio, fecha_fin)
        end)

        if movimientos_rango != [] do
          IO.puts("\n Movimientos en el rango:")
          Enum.each(movimientos_rango, fn m ->
            IO.puts("  #{m.fecha} - #{m.codigo} - #{m.tipo} - #{m.cantidad}")
          end)
        end

      {:error, razon} ->
        IO.puts(" Error: #{razon}")
    end

    menu_principal()
  end

  defp eliminar_duplicados_menu() do
    IO.puts("\n ELIMINAR PIEZAS DUPLICADAS")
    IO.puts("===========================")

    case leer_piezas("piezas.csv") do
      {:ok, piezas} ->
        piezas_sin_duplicados = eliminar_duplicados(piezas)

        if length(piezas_sin_duplicados) == length(piezas) do
          IO.puts(" No se encontraron duplicados")
        else
          guardar_piezas(piezas_sin_duplicados, "piezas.csv")
          IO.puts(" Duplicados eliminados")
          IO.puts("Piezas antes: #{length(piezas)}")
          IO.puts("Piezas después: #{length(piezas_sin_duplicados)}")
        end

      {:error, razon} ->
        IO.puts(" Error: #{razon}")
    end

    menu_principal()
  end

  defp guardar_y_salir() do
    IO.puts("\n GUARDANDO DATOS...")
    actualizar_inventario()
    IO.puts(" Datos guardados exitosamente")
    IO.puts(" ¡Hasta pronto!")
    System.halt(0)
  end


  def leer_piezas(nombre_archivo) do
    case File.read(nombre_archivo) do
      {:ok, ""} -> {:ok, []}
      {:ok, contenido} ->
        lineas = String.split(contenido, "\n", trim: true)
        procesar_lineas_piezas(lineas, [])
      {:error, _} -> {:ok, []}
    end
  end

  defp procesar_lineas_piezas([], acum), do: {:ok, Enum.reverse(acum)}

  defp procesar_lineas_piezas([linea | rest], acum) do
    case String.split(linea, ",", trim: true) do
      [codigo, nombre, valor_str, unidad, stock_str] ->
        with {valor, ""} <- Integer.parse(valor_str),
             {stock, ""} <- Integer.parse(stock_str) do
          pieza = %Pieza{
            codigo: codigo,
            nombre: nombre,
            valor: valor,
            unidad: unidad,
            stock: stock
          }
          procesar_lineas_piezas(rest, [pieza | acum])
        else
          _ -> {:error, "Datos inválidos en línea: #{linea}"}
        end
      _ -> {:error, "Formato inválido en línea: #{linea}"}
    end
  end

  def leer_movimientos(nombre_archivo) do
    case File.read(nombre_archivo) do
      {:ok, ""} -> {:ok, []}
      {:ok, contenido} ->
        lineas = String.split(contenido, "\n", trim: true)
        procesar_lineas_movimientos(lineas, [])
      {:error, _} -> {:ok, []}
    end
  end

  defp procesar_lineas_movimientos([], acum), do: {:ok, Enum.reverse(acum)}

  defp procesar_lineas_movimientos([linea | rest], acum) do
    case String.split(linea, ",", trim: true) do
      [codigo, tipo, cantidad_str, fecha] ->
        with {cantidad, ""} <- Integer.parse(cantidad_str) do
          movimiento = %Movimiento{
            codigo: codigo,
            tipo: tipo,
            cantidad: cantidad,
            fecha: fecha
          }
          procesar_lineas_movimientos(rest, [movimiento | acum])
        else
          _ -> {:error, "Cantidad inválida en línea: #{linea}"}
        end
      _ -> {:error, "Formato inválido en línea: #{linea}"}
    end
  end

  defp guardar_piezas(piezas, archivo) do
    lineas = Enum.map(piezas, fn p ->
      "#{p.codigo},#{p.nombre},#{p.valor},#{p.unidad},#{p.stock}"
    end)
    File.write!(archivo, Enum.join(lineas, "\n"))
  end

  defp guardar_movimientos(movimientos, archivo) do
    lineas = Enum.map(movimientos, fn m ->
      "#{m.codigo},#{m.tipo},#{m.cantidad},#{m.fecha}"
    end)
    File.write!(archivo, Enum.join(lineas, "\n"))
  end

  defp actualizar_inventario() do
    with {:ok, piezas} <- leer_piezas("piezas.csv"),
         {:ok, movimientos} <- leer_movimientos("movimientos.csv") do

      piezas_actualizadas = aplicar_movimientos(piezas, movimientos)
      guardar_piezas(piezas_actualizadas, "inventario_actual.csv")
      :ok
    else
      _ -> :error
    end
  end

  defp aplicar_movimientos(piezas, movimientos) do
    Enum.map(piezas, fn pieza ->
      movimientos_pieza = Enum.filter(movimientos, fn m -> m.codigo == pieza.codigo end)
      stock_actualizado = calcular_stock_actualizado(pieza.stock, movimientos_pieza)
      %{pieza | stock: stock_actualizado}
    end)
  end

  defp calcular_stock_actualizado(stock_inicial, movimientos) do
    Enum.reduce(movimientos, stock_inicial, fn movimiento, stock ->
      case movimiento.tipo do
        "ENTRADA" -> stock + movimiento.cantidad
        "SALIDA" -> stock - movimiento.cantidad
      end
    end)
  end

  # Funciones recursivas

  def contar_stock_bajo(piezas, t) do
    contar_stock_bajo_rec(piezas, t, 0)
  end

  defp contar_stock_bajo_rec([], _t, contador), do: contador
  defp contar_stock_bajo_rec([%Pieza{stock: stock} | rest], t, contador) do
    if stock < t do
      contar_stock_bajo_rec(rest, t, contador + 1)
    else
      contar_stock_bajo_rec(rest, t, contador)
    end
  end

  def cantidad_movida_rango(movimientos, {fini, ffin}) do
    cantidad_movida_rango_rec(movimientos, fini, ffin, 0)
  end

  defp cantidad_movida_rango_rec([], _fini, _ffin, total), do: total
  defp cantidad_movida_rango_rec([movimiento | rest], fini, ffin, total) do
    if fecha_en_rango?(movimiento.fecha, fini, ffin) do
      cantidad_movida_rango_rec(rest, fini, ffin, total + movimiento.cantidad)
    else
      cantidad_movida_rango_rec(rest, fini, ffin, total)
    end
  end

  defp fecha_en_rango?(fecha, fini, ffin) do
    fecha >= fini and fecha <= ffin
  end

  def eliminar_duplicados(piezas) do
    eliminar_duplicados_rec(piezas, [], MapSet.new())
  end

  defp eliminar_duplicados_rec([], resultado, _vistos), do: Enum.reverse(resultado)
  defp eliminar_duplicados_rec([pieza | rest], resultado, vistos) do
    if MapSet.member?(vistos, pieza.codigo) do
      eliminar_duplicados_rec(rest, resultado, vistos)
    else
      nuevos_vistos = MapSet.put(vistos, pieza.codigo)
      eliminar_duplicados_rec(rest, [pieza | resultado], nuevos_vistos)
    end
  end
end

# Iniciar el sistema
SistemaInventario.iniciar_sistema()
