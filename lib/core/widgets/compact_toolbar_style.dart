import 'package:flutter/material.dart';

/// Estilo compacto para la barra de herramientas de Students/Attendance
/// (By Alphabet / Add Group / Add Student / QR). El `FilledButton`/
/// `TextButton` de Material 3 por defecto es demasiado ancho (padding +
/// tamaño mínimo de touch target ~48dp) para entrar 4 elementos en una
/// sola línea en pantallas angostas — confirmado en un Honor/Huawei real
/// con `wm size`/`wm density`: 320dp lógicos de ancho (no 360+ como en un
/// teléfono de gama media), y el usuario además tenía "texto más grande"
/// activado en el sistema, reduciendo el espacio disponible todavía más.
/// La app real usa botones chicos tipo pastilla con padding ajustado —
/// esto imita eso lo suficiente para que las 4 piezas entren en una fila.
const kCompactToolbarButtonStyle = ButtonStyle(
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  ),
  minimumSize: WidgetStatePropertyAll(Size(0, 32)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: WidgetStatePropertyAll(
    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  ),
);

const kCompactToolbarTextButtonStyle = ButtonStyle(
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  ),
  minimumSize: WidgetStatePropertyAll(Size(0, 32)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
);
