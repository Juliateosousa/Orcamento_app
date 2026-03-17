import 'package:flutter/material.dart';

// ======================================================
//      CLASSES AUXILIARES (INTENTS + LINHA FOLHA)
// ======================================================

class MoveLeftIntent extends Intent {
  const MoveLeftIntent();
}

class MoveRightIntent extends Intent {
  const MoveRightIntent();
}

class MoveUpIntent extends Intent {
  const MoveUpIntent();
}

class MoveDownIntent extends Intent {
  const MoveDownIntent();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class LinhaFolha {
  final TextEditingController folhasController; // 👈 NOVO (Qtd Folhas)
  final TextEditingController qtdController;
  final TextEditingController compController;
  final TextEditingController largController;

  final FocusNode folhasFocus; // 👈 NOVO
  final FocusNode qtdFocus;
  final FocusNode compFocus;
  final FocusNode largFocus;

  LinhaFolha({
    String? folhas,
    String? qtd,
    String? comp,
    String? larg,
  })  : folhasController = TextEditingController(text: folhas ?? ''),
        qtdController = TextEditingController(text: qtd ?? ''),
        compController = TextEditingController(text: comp ?? ''),
        largController = TextEditingController(text: larg ?? ''),
        folhasFocus = FocusNode(),
        qtdFocus = FocusNode(),
        compFocus = FocusNode(),
        largFocus = FocusNode();

  Map<String, dynamic> toMap() {
    return {
      'qtdFolhas': folhasController.text.trim(), // 👈 NOVO
      'quantidade': qtdController.text.trim(),
      'comprimento': compController.text.trim(),
      'largura': largController.text.trim(),
    };
  }
}

// helper class (top-level)
class FolhaCalc {
  final double? tamanhoM2;
  final double? quantidade;
  final double? total;
  final bool usouQtdFolhas;

  FolhaCalc({
    required this.tamanhoM2,
    required this.quantidade,
    required this.total,
    required this.usouQtdFolhas,
  });
}

class LinhaMadeira {
  final TextEditingController qtdController;
  final TextEditingController compController;
  final TextEditingController largController;
  final TextEditingController altController;

  final FocusNode qtdFocus;
  final FocusNode compFocus;
  final FocusNode largFocus;
  final FocusNode altFocus;

  String lados; // "3", "4" ou "5"

  LinhaMadeira({
    String? qtd,
    String? comp,
    String? larg,
    String? alt,
    String? lados,
  })  : qtdController = TextEditingController(text: qtd ?? ''),
        compController = TextEditingController(text: comp ?? ''),
        largController = TextEditingController(text: larg ?? ''),
        altController = TextEditingController(text: alt ?? ''),
        qtdFocus = FocusNode(),
        compFocus = FocusNode(),
        largFocus = FocusNode(),
        altFocus = FocusNode(),
        lados = (lados == '3' || lados == '4' || lados == '5')
            ? lados!
            : '4';

  Map<String, dynamic> toMap() => {
        'quantidade': qtdController.text.trim(),
        'comprimento': compController.text.trim(),
        'largura': largController.text.trim(),
        'altura': altController.text.trim(),
        'lados': lados,
      };
}

// pequena classe pra representar posição da célula
class Posicao {
  final int linha;
  final int coluna;
  Posicao(this.linha, this.coluna);
}