import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import 'aux_and_helpers.dart';

import 'dart:async';
import 'package:intl/intl.dart';

const int colQtd = 0;
const int colComp = 1;
const int colLarg = 2;
const int colFolhas = 3;
const int colMax = colFolhas;

String formatarData(dynamic createdAt) {
  if (createdAt == null) return '-';

  final DateTime date = (createdAt as Timestamp).toDate();
  return DateFormat('dd/MM/yy').format(date);
}

Future<void> initFirestore() async {
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }
}

// ======================================================
//                   PÁGINA DE ORÇAMENTO
// ======================================================

class OrcamentoPage extends StatefulWidget {
  final String clienteId;
  final String clienteNome; 
  final String orcamentoId;
  final int numeroOrcamento;

  const OrcamentoPage({
    super.key,
    required this.clienteId,
    required this.orcamentoId,
    required this.numeroOrcamento,
    required this.clienteNome,
  });
  
  @override
  State<OrcamentoPage> createState() => _OrcamentoPageState();
}

class _OrcamentoPageState extends State<OrcamentoPage> {
  Timer? _saveTimer;
  bool _isFabHovered = false;
  final ScrollController _scrollCtrl = ScrollController();
  final PageStorageKey<String> _orcamentoScrollKey =
    const PageStorageKey<String>('orcamentoScroll');
  late final Stream<QuerySnapshot> _moveisStream;

  // Controllers
  final TextEditingController ppController = TextEditingController();
  final TextEditingController clienteController = TextEditingController();
  final TextEditingController telefoneClienteController =
      TextEditingController();
  final TextEditingController arquitetoController = TextEditingController();
  bool _criandoVernizPu = false; // 🔒 trava para não criar 2x
  bool _criandoVernizComum = false;
  // Mapa com total geral de cada móvel (por id)
  final Set<String> _moveisJaInicializados = {};
  final Map<String, double> _totaisGeraisPorMovel = {};
  final ValueNotifier<double> _totalOrcamentoNotifier = ValueNotifier<double>(0.0);
    final TextEditingController freteController = TextEditingController();
  final TextEditingController extraController = TextEditingController();
  final TextEditingController maoDeObraController = TextEditingController();
  final TextEditingController percentualController = TextEditingController(); // %
  // OBS (por móvel)
  final Map<String, TextEditingController> _obsControllers = {};

  

  /// Atualiza o total de UM móvel e recalcula o total do orçamento.
  /// Evita rebuild desnecessário se o valor não mudou.

  String? clienteSelecionadoId;

// Controllers para os campos de resumo (por móvel)
final Map<String, TextEditingController> _freteControllers = {};
final Map<String, TextEditingController> _almocoControllers = {};
final Map<String, TextEditingController> _maoObraControllers = {};
final Map<String, TextEditingController> _lucroControllers = {};

DocumentReference get _orcamentoRef {
  return FirebaseFirestore.instance
      .collection('clientes')
      .doc(widget.clienteId)
      .collection('orcamentos')
      .doc(widget.orcamentoId);
}

Widget _linhaResumo({
  required String label,
  required TextEditingController controller,
  required VoidCallback onSave,
  required VoidCallback onChange,
  double width = 90,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      SizedBox(
        width: 160,
        child: Text(
          "$label:",
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13),
        ),
      ),
        const SizedBox(width: 8),
        SizedBox(
          width: width,
          height: 40,
          child: TextFormField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChange(),
            onEditingComplete: onSave,
          ),
        ),
      ],
    ),
  );
}

TextEditingController _getOrCreateResumoController(
  Map<String, TextEditingController> map,
  String movelId, {
  String? initialText,
}) {
  if (map.containsKey(movelId)) {
    return map[movelId]!;
  }

  final ctrl = TextEditingController(text: initialText ?? "");
  map[movelId] = ctrl;
  return ctrl;
}

TextEditingController _getOrCreateObsController(String movelId, {String? initial}) {
  if (_obsControllers.containsKey(movelId)) return _obsControllers[movelId]!;
  final c = TextEditingController(text: initial ?? "");
  _obsControllers[movelId] = c;
  return c;
}

// 👇 nome diferente para não conflitar com seu _toDouble já existente
double _parseResumoDouble(String? value) {
  if (value == null) return 0;
  final t = value.replaceAll(',', '.').trim();
  if (t.isEmpty) return 0;
  return double.tryParse(t) ?? 0;
}

Future<void> _salvarResumoTodosMoveis() async {
  try {
    // busca todos os móveis desse orçamento
    final snap = await FirebaseFirestore.instance
        .collection('moveis')
        .where('numeroOrcamento', isEqualTo: widget.numeroOrcamento)
        .get();

    for (final doc in snap.docs) {
      final movelId = doc.id;

      final freteCtrl = _freteControllers[movelId];
      final extraCtrl = _almocoControllers[movelId];
      final maoObraCtrl = _maoObraControllers[movelId];
      final lucroCtrl = _lucroControllers[movelId];

      // só salva o que existe na tela (controllers criados)
      if (freteCtrl == null &&
          extraCtrl == null &&
          maoObraCtrl == null &&
          lucroCtrl == null) {
        continue;
      }

      await doc.reference.update({
        'frete': freteCtrl == null ? FieldValue.delete() : _parseResumoDouble(freteCtrl.text),
        'extra': extraCtrl == null ? FieldValue.delete() : _parseResumoDouble(extraCtrl.text),
        'maoObra': maoObraCtrl == null ? FieldValue.delete() : _parseResumoDouble(maoObraCtrl.text),
        'lucroPercentual': lucroCtrl == null ? FieldValue.delete() : _parseResumoDouble(lucroCtrl.text),
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Resumo salvo com sucesso.")),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erro ao salvar resumo: $e")),
    );
  }
}

Future<void> _editValorTotalDialog(
  DocumentSnapshot itemDoc,
  String itemName,
) async {
  final data = itemDoc.data() as Map<String, dynamic>? ?? {};

  final nomeAtual = (data['itemName'] ?? data['name'] ?? itemName) as String;
  final precoAtual = data['precoUnd'];
  final qtdAtual = data['quantidadeUnd'];

  // ✅ NEW: medida salva no item do móvel
  final String medidaAtual =
      (data['medidaValorTotal'] as String?) ?? "Und";

  final nomeController = TextEditingController(text: nomeAtual);
  final precoController = TextEditingController(
    text: precoAtual == null ? '' : precoAtual.toString(),
  );
  final qtdController = TextEditingController(
    text: qtdAtual == null ? '' : qtdAtual.toString(),
  );

  double? parse(String t) => double.tryParse(t.replaceAll(',', '.'));

  // ✅ options (3 examples)
  const medidaOptions = ["Und", "m³", "m²", "m", "L"];

  await showDialog(
    context: context,
    builder: (ctx) {
      String medidaSelecionada = medidaAtual;

      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text('Valor Total - $nomeAtual'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nome só para ESTE móvel
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(
                      labelText: "Nome",
                      hintText: "Ex: Total marcenaria",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ NEW: dropdown de medida
                  DropdownButtonFormField<String>(
                    initialValue: medidaOptions.contains(medidaSelecionada)
                        ? medidaSelecionada
                        : medidaOptions.first,
                    items: medidaOptions
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setStateDialog(() {
                        medidaSelecionada = v ?? "Und";
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Medida",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Preço / und só para ESTE móvel
                  TextField(
                    controller: precoController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Preço (R\$)",
                      hintText: "Ex: 1500.00",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantidade só para ESTE móvel
                  TextField(
                    controller: qtdController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Quantidade",
                      hintText: "Ex: 1",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () async {
                  final novoNome = nomeController.text.trim();
                  final preco = parse(precoController.text.trim());
                  final qtd = parse(qtdController.text.trim());

                  try {
                    await itemDoc.reference.update({
                      'itemName': novoNome.isEmpty ? nomeAtual : novoNome,
                      'precoUnd': preco,
                      'quantidadeUnd': qtd,


                      // ✅ NEW: salva a medida escolhida
                      'medidaValorTotal': medidaSelecionada,
                    });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Valor total atualizado para "${novoNome.isEmpty ? nomeAtual : novoNome}".',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Erro ao salvar Valor Total: $e"),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  "Salvar",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _carregarCabecalhoOrcamento() async {
  final docRef = FirebaseFirestore.instance
      .collection('clientes')
      .doc(widget.clienteId)
      .collection('orcamentos')
      .doc(widget.orcamentoId);

  final snap = await docRef.get();
  final data = snap.data();

  if (data == null) return;

  // Se você já salvou como double, converte para string aqui
  setState(() {
    freteController.text = (data['frete'] ?? '').toString();
    extraController.text = (data['extra'] ?? '').toString();
    maoDeObraController.text = (data['maoDeObra'] ?? '').toString();
    percentualController.text = (data['percentual'] ?? '').toString();
  });
}

    // ====== RESUMO POR MÓVEL (FRETE / ALMOÇO / MÃO DE OBRA / LUCRO) ======

Future<int> _gerarProximoNumeroMovelGlobal() async {
  final db = FirebaseFirestore.instance;
  final counterRef = db.collection('config').doc('movel_counter');

  return db.runTransaction<int>((transaction) async {
    final snap = await transaction.get(counterRef);

    int ultimo = 0;
    if (snap.exists) {
      final data = snap.data() ?? {};
      final raw = data['ultimoNumeroMovel'];
      if (raw is int) {
        ultimo = raw;
      } else if (raw is num) {
        ultimo = raw.toInt();
      }
    }

    final proximo = ultimo + 1;

    transaction.set(
      counterRef,
      {'ultimoNumeroMovel': proximo},
      SetOptions(merge: true),
    );

    return proximo;
  });
}

Future<void> _gerarPdfOrcamento() async {
  try {
    final pdf = pw.Document();

    // 1) Busca todos os móveis deste orçamento
    final moveisQuery = await FirebaseFirestore.instance
        .collection('moveis')
        .where('numeroOrcamento', isEqualTo: widget.numeroOrcamento)
        .get();

    if (moveisQuery.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum móvel para gerar PDF.")),
      );
      return;
    }

    final moveisDocs = moveisQuery.docs.toList();
    moveisDocs.sort((a, b) {
    final da = (a.data() as Map<String, dynamic>? ?? {});
    final db = (b.data() as Map<String, dynamic>? ?? {});

    final na = (da['numeroMovel'] as num?)?.toInt() ?? 0;
    final nb = (db['numeroMovel'] as num?)?.toInt() ?? 0;

    return na.compareTo(nb);
  });

    for (final movelDoc in moveisDocs) {
      final movelData = movelDoc.data() as Map<String, dynamic>? ?? {};
      final nomeMovel = movelData['nome'] as String? ?? "(sem nome)";
      final int? numeroMovel = movelData['numeroMovel'] as int?;

      // 2) Itens do móvel
      final itensSnap = await movelDoc.reference
          .collection('itens')
          .orderBy('createdAt', descending: false)
          .get();
      final itensDocs = itensSnap.docs;

      // =====================================================
      // 2.1 – PRIMEIRA PASSAGEM: calcular valores dos itens
      // =====================================================
      final List<_PdfLinhaItem> linhasPdf = [];
      double totalBruto = 0.0;

      // Áreas auxiliares para verniz
      final double areaMadeiraPu =
          _calcularAreaM2VernizParaMovel(itensDocs, paraVernizPu: true);
      final double areaMadeiraComum =
          _calcularAreaM2VernizParaMovel(itensDocs, paraVernizPu: false);
      final double areaLaminas =
          _calcularAreaM2TotalLaminas(itensDocs);

      for (final itemDoc in itensDocs) {
        final itemData = itemDoc.data() as Map<String, dynamic>? ?? {};
        final itemName = itemData['itemName'] as String? ?? "(sem nome)";
        final unitType = itemData['unitType'];
        final subcategoryItem = itemData['subcategory'];
        final subLower =
            (subcategoryItem as String?)?.toLowerCase() ?? '';

        final bool isFolha = unitType == 'folha';
        final bool isColaBranca =
            unitType == 'litro' && itemName.toLowerCase() == 'cola branca';
        final bool isColaFormica =
            unitType == 'litro' && itemName.toLowerCase() == 'cola formica';
        final bool isUnidade = unitType == 'unidade';
        final bool isFita = subLower == 'fita' || subLower == 'fitas';
        final bool isOutros = subLower == 'outros' || subLower == 'outro';
        final bool isPintura =
            unitType == 'litro' && subLower == 'tintas';
        final bool isMadeiraMacica = unitType == 'madeiraMacica';
        final bool isVernizPu =
            unitType == 'litro' && itemName.toLowerCase() == 'verniz pu';
        final bool isVernizComum =
            unitType == 'litro' && itemName.toLowerCase() == 'verniz comum';
        final bool isValorTotal = isUnidade && (itemData['isValorTotal'] == true);


        final medidaUsada = _toDouble(itemData['medidaUsada']);
        final quantidadeUsada = _toDouble(itemData['quantidadeUsada']);
        final precoPorQuantidade = _toDouble(itemData['precoPorQuantidade']);
        final unidadeMedida = _unitSuffix(unitType as String?);

// --- FOLHA ---
final linhasFolha = (itemData['linhas'] as List?) ?? [];
final double? areaFolha = _toDouble(itemData['areaFolha']); // m² por folha
final double? precoFolha = _toDouble(itemData['precoFolha']);
final double taxaPerca = _toDouble(itemData['taxaPerca']) ?? 0;

double? tamanhoFolha;     // m² total
double? quantidadeFolha;  // nº de folhas
double? totalFolha;

if (isFolha) {
  double somaM2 = 0;
  double somaFolhas = 0;
  bool usouQtdFolhas = false;

  for (final raw in linhasFolha) {
    if (raw is! Map<String, dynamic>) continue;

    final qFolhas = _toDouble(raw['qtdFolhas']);

    if (qFolhas != null && qFolhas > 0 && areaFolha != null && areaFolha > 0) {
      usouQtdFolhas = true;
      somaFolhas += qFolhas;
      somaM2 += qFolhas * areaFolha;
      continue;
    }

    final q = _toDouble(raw['quantidade']);
    final c = _toDouble(raw['comprimento']);
    final g = _toDouble(raw['largura']);
    if (q != null && c != null && g != null) {
      somaM2 += q * (c * g / 10000.0);
    }
  }

  if (somaM2 > 0) tamanhoFolha = somaM2;

  // ✅ perda como fator de AUMENTO
  final fatorPerca = 1.0 + (taxaPerca / 100.0);

  if (somaFolhas > 0) {
    quantidadeFolha = usouQtdFolhas
        ? somaFolhas
        : somaFolhas * fatorPerca;
  } else if (tamanhoFolha != null && areaFolha != null && areaFolha > 0) {
    quantidadeFolha = (tamanhoFolha / areaFolha) * fatorPerca;
  }

  if (quantidadeFolha != null && precoFolha != null) {
    totalFolha = precoFolha * quantidadeFolha!;
  }
}

       // ====== UNIDADE ======
final double? quantidadeUnd = _toDouble(itemData['quantidadeUnd']);
final double? precoUnidadeItem = _toDouble(itemData['precoUnidade']); // preço da tabela
final double? precoUndMovel    = _toDouble(itemData['precoUnd']);     // preço customizado do "Valor Total"

// usa o mesmo itemName que você já tem lá em cima

double? totalUnidade;

if (isUnidade && quantidadeUnd != null) {
  if (isValorTotal) {
    // ⭐ Valor Total: usa o precoUnd (se existir) senão cai pro precoUnidade da tabela
    final double? precoBase = precoUndMovel ?? precoUnidadeItem;
    if (precoBase != null) {
      totalUnidade = quantidadeUnd * precoBase;
    }
  } else {
    // Unidade normal
    if (precoUnidadeItem != null) {
      totalUnidade = quantidadeUnd * precoUnidadeItem;
    }
  }
}

        // --- COLA BRANCA ---
        final litrosColaBranca = _toDouble(itemData['litros']);
        final precoLColaBranca = _toDouble(itemData['precoL']);
        double? totalColaBranca;
        if (isColaBranca &&
            litrosColaBranca != null &&
            precoLColaBranca != null) {
          totalColaBranca = litrosColaBranca * precoLColaBranca;
        }

        // --- FITA ---
        final metrosFitaItem = _toDouble(itemData['metrosFita']);
        final precoTotalFitaItem = _toDouble(itemData['precoMetro']);
        final metragemItem = _toDouble(itemData['metragem']);

        double? totalFita;
        double? precoPorMetroFitaLinha;
        double? quantidadeFitaItem;
        if ((isFita || isOutros) &&
            metrosFitaItem != null &&
            precoTotalFitaItem != null &&
            metragemItem != null &&
            metragemItem > 0) {
          precoPorMetroFitaLinha = precoTotalFitaItem / metragemItem;
          totalFita = metrosFitaItem * precoPorMetroFitaLinha;
          quantidadeFitaItem = metrosFitaItem / metragemItem;
        }

        // --- PINTURA ---
        final precoM2Pintura = _toDouble(itemData['precoM2']);
        double? pinturaM2;
        double? quantidadePintura;
        double? totalPintura;

        if (isPintura) {
          final linhasPintura = (itemData['linhasPintura'] as List?) ?? [];
          final bool arredondarQtde =
              itemData['arredondarQuantidade'] == true;

          double somaM2 = 0;

          for (final l in linhasPintura) {
            if (l is Map<String, dynamic>) {
              final q = _toDouble(l['quantidade']);
              final c = _toDouble(l['comprimento']);
              final g = _toDouble(l['largura']);

              if (q != null && c != null && g != null) {
                somaM2 += q * (c * g / 10000.0); // cm² → m²
              }
            }
          }

          if (somaM2 > 0) {
            pinturaM2 = somaM2;

            quantidadePintura =
                arredondarQtde ? somaM2.ceilToDouble() : somaM2;

            if (precoM2Pintura != null) {
              totalPintura = arredondarQtde
                  ? quantidadePintura! * precoM2Pintura * 1.20
                  : pinturaM2 * precoM2Pintura * 1.20;
            }
          }
        }

        // --- MADEIRA MACIÇA ---
        final volumeCm3 = _calcularVolumeM3Madeira(itemDoc); // cm³
        final precoM3 = _toDouble(itemData['precoM3']) ?? 0;

        final double quantidadeM3 = volumeCm3 / 1000000; // cm³ → m³
        final double totalMadeiraMacica = quantidadeM3 * precoM3;


        // --- VERNIZ PU / COMUM ---
        double? vernizPuM2;
        double? vernizPuLitros;
        double? totalVernizPu;

        double? vernizComumM2;
        double? vernizComumLitros;
        double? totalVernizComum;

        if (isVernizPu) {
          final double areaTotal = areaMadeiraPu + areaLaminas;
          if (areaTotal > 0) {
            vernizPuM2 = areaTotal;
            vernizPuLitros = areaTotal;
            final precoM2 = _toDouble(itemData['precoM2']);
            if (precoM2 != null) {
              totalVernizPu = precoM2 * areaTotal;
            }
          }
        }

        if (isVernizComum) {
          final double areaTotal = areaMadeiraComum;
          if (areaTotal > 0) {
            vernizComumM2 = areaTotal;
            vernizComumLitros = areaTotal;
            final precoM2 = _toDouble(itemData['precoM2']);
            if (precoM2 != null) {
              totalVernizComum = precoM2 * areaTotal;
            }
          }
        }

        // --- COLA FORMICA ---
        double? colaLitrosTotal;
        double? colaPrecoL;

        if (isColaFormica) {
          final double lm2Mdf = _toDouble(itemData['lm2Mdf']) ?? 0;
          final double lm2Formica = _toDouble(itemData['lm2Formica']) ?? 0;
          colaPrecoL = _toDouble(itemData['precoL']);

          double somaLitros = 0;

          final listaItens = (itemData['colaFormicaItens'] as List?) ?? [];
          for (final cfg in listaItens) {
            if (cfg is Map<String, dynamic>) {
              final id = cfg['itemMovelId'] as String?;
              if (id == null) continue;

              DocumentSnapshot? alvo;
              for (final d in itensDocs) {
                if (d.id == id) {
                  alvo = d;
                  break;
                }
              }
              if (alvo == null) continue;

              somaLitros += _calcularLitrosColaFormicaParaItem(
                alvo,
                lm2Mdf,
                lm2Formica,
              );

              final dataAlvo =
                  alvo.data() as Map<String, dynamic>? ?? {};
              final unitTypeAlvo =
                  (dataAlvo['unitType'] as String?)?.toLowerCase() ?? '';
              final subAlvo =
                  (dataAlvo['subcategory'] as String?)?.toLowerCase() ?? '';

              if (unitTypeAlvo != 'litro') {
                if (subAlvo.contains('fita')) {
                      0;
                } else {
                }
              }
            }
          }

          final extraLitros = _toDouble(itemData['extraLitros']) ?? 0;
          somaLitros += extraLitros;

          if (somaLitros > 0) colaLitrosTotal = somaLitros;
        }

        // =============== TOTAL DO ITEM (mesma lógica da tela) ===============
        double totalItem = 0;
        if (isFolha && totalFolha != null) {
          totalItem = totalFolha;
        } else if (isUnidade && totalUnidade != null) {
          totalItem = totalUnidade;
        } else if (isColaFormica &&
            colaLitrosTotal != null &&
            colaPrecoL != null) {
          totalItem = colaLitrosTotal * colaPrecoL;
        } else if (isColaBranca && totalColaBranca != null) {
          totalItem = totalColaBranca;
        } else if ((isFita || isOutros) && totalFita != null) {
          totalItem = totalFita;
        } else if (isPintura && totalPintura != null) {
          totalItem = totalPintura;
        } else if (isVernizPu && totalVernizPu != null) {
          totalItem = totalVernizPu;
        } else if (isVernizComum && totalVernizComum != null) {
          totalItem = totalVernizComum;
        } else if (isMadeiraMacica) {
          totalItem = totalMadeiraMacica;
        } else if (!isFolha &&
            !isUnidade &&
            !isColaFormica &&
            !isColaBranca &&
            !isFita &&
            !isOutros &&
            !isPintura) {
          final q = quantidadeUsada;
          final p = precoPorQuantidade;
          if (q != null && p != null) {
            totalItem = q * p;
          }
        }

        totalBruto += totalItem;

        // ===================== Strings para o PDF =====================

        // MEDIDA
        String medidaTxt;
        if (isColaFormica || isColaBranca || isPintura || isVernizPu || isVernizComum) {
          medidaTxt = "L";
        } else if (isMadeiraMacica) {
          medidaTxt = "m³";
        } else if (isFita || isOutros) {
          medidaTxt = "m";
        } else if (isFolha) {
          medidaTxt = "m²";
        } else if (isUnidade) {
          medidaTxt = "Und";
        } else if (medidaUsada != null) {
          medidaTxt = "${_formatDecimal(medidaUsada)} $unidadeMedida";
        } else {
          medidaTxt = "-";
        }

        // QUANTIDADE
        String quantidadeTxt;
        if (isColaFormica) {
          if (colaLitrosTotal == null) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(colaLitrosTotal);
          }
        } else if (isVernizPu) {
          if (vernizPuLitros == null || vernizPuLitros == 0) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(vernizPuLitros);
          }
        } else if (isVernizComum) {
          if (vernizComumLitros == null || vernizComumLitros == 0) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(vernizComumLitros);
          }

        } else if (isMadeiraMacica) {
          if (quantidadeM3 <= 0){
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(quantidadeM3/1000000);
          }

        } else if (isColaBranca) {
          if (litrosColaBranca == null) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(litrosColaBranca);
          }
        } else if (isFita || isOutros) {
          if (quantidadeFitaItem == null) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(quantidadeFitaItem);
          }
        } else if (isFolha) {
          if (quantidadeFolha == null) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(quantidadeFolha);
          }
        } else if (isUnidade) {
          if (quantidadeUnd == null) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(quantidadeUnd);
          }
        } else if (isPintura) {
          if (quantidadePintura == null) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt =
                _formatDecimal(quantidadePintura * 1.20); // sem "m²"
          }
        } else {
          final q = quantidadeUsada;
          if (q == null) {
            quantidadeTxt = "-";
          } else {
            quantidadeTxt = _formatDecimal(q);
          }
        }

        // PREÇO (unitário)
        String precoTxt;
        if (isFolha && precoFolha != null) {
          precoTxt = "R\$ ${_formatDecimal(precoFolha, dec: 2)}";
        } else if (isUnidade) {
          // 🔹 Trata "Valor Total" usando precoUndMovel se existir
          double? precoBase;
          if (isValorTotal) {
            precoBase = precoUndMovel ?? precoUnidadeItem;
          } else {
            precoBase = precoUnidadeItem;
          }

          if (precoBase != null) {
            precoTxt = "R\$ ${_formatDecimal(precoBase, dec: 2)}";
          } else {
            precoTxt = "-";
          }
        } else if (isColaFormica && colaPrecoL != null) {
          precoTxt = "R\$ ${_formatDecimal(colaPrecoL, dec: 2)}";
        } else if (isColaBranca && precoLColaBranca != null) {
          precoTxt = "R\$ ${_formatDecimal(precoLColaBranca, dec: 2)}";
        } else if ((isFita || isOutros) && precoPorMetroFitaLinha != null) {
          precoTxt =
              "R\$ ${_formatDecimal(precoPorMetroFitaLinha, dec: 2)}";
        } else if (isPintura && precoM2Pintura != null) {
          precoTxt = "R\$ ${_formatDecimal(precoM2Pintura, dec: 2)}";
        } else if ((isVernizPu || isVernizComum) &&
            precoM2Pintura != null) {
          precoTxt = "R\$ ${_formatDecimal(precoM2Pintura, dec: 2)}";
        } else if (isMadeiraMacica && precoM3 > 0) {
          precoTxt = "R\$ ${_formatDecimal(precoM3, dec: 2)}/m³";
        } else if (precoPorQuantidade != null) {
          precoTxt =
              "R\$ ${_formatDecimal(precoPorQuantidade, dec: 2)}";
        } else {
          precoTxt = "-";
        }

        // TOTAL
        String totalTxt;
        if (totalItem <= 0) {
          totalTxt = "-";
        } else {
          totalTxt = "R\$ ${_formatDecimal(totalItem, dec: 2)}";
        }

        // Esconde verniz sem área
        if (isVernizPu && (vernizPuM2 == null || vernizPuM2 == 0)) {
          continue;
        }
        if (isVernizComum && (vernizComumM2 == null || vernizComumM2 == 0)) {
          continue;
        }

        linhasPdf.add(
          _PdfLinhaItem(
            itemName: itemName,
            medida: medidaTxt,
            quantidade: quantidadeTxt,
            preco: precoTxt,
            total: totalTxt,
          ),
        );
      }

      // =====================================================
      // 3) RESUMO (Frete / Extra / Mão de Obra / Lucro / Total Geral)
      // =====================================================
      final freteCtrl =
          _getOrCreateResumoController(_freteControllers, movelDoc.id);
      final almocoCtrl =
          _getOrCreateResumoController(_almocoControllers, movelDoc.id);
      final maoObraCtrl =
          _getOrCreateResumoController(_maoObraControllers, movelDoc.id);
      final lucroCtrl =
          _getOrCreateResumoController(_lucroControllers, movelDoc.id);

      double frete = _toDouble(freteCtrl.text) ?? 0;
      double almoco = _toDouble(almocoCtrl.text) ?? 0;
      double maoObra = _toDouble(maoObraCtrl.text) ?? 0;
      double lucro = _toDouble(lucroCtrl.text) ?? 0;

      final base = totalBruto + frete + almoco + maoObra;
      final totalGeral = base * (1 + (lucro / 100.0));
      final String obsMovel =
        (movelData['obs'] ?? '').toString().trim();

      // =====================================================
      // 4) Montar a página do PDF
      // =====================================================
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ===== CABEÇALHO =====
                pw.Text(
                  "Espart Moveis",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Endereço / telefone
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Rua Adel Nogueira Maia, 300 - Messejana",
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            "Telefone: (085)3276-1956 / 3276-5621",
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    // PP na 1ª linha, Nº do móvel na 2ª linha (ambos à direita)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "PP: ${ppController.text} / Emissão: ${formatarData(movelData['createdAt'])}",
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (numeroMovel != null)
                          pw.Text(
                            "Nº do Móvel: $numeroMovel",
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                // Cliente
                pw.Row(
                  children: [
                    pw.Text(
                      "Cliente: ",
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        widget.clienteNome,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),

                // Arquiteto
                pw.Row(
                  children: [
                    pw.Text(
                      "Arquiteto: ",
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        arquitetoController.text,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),

                // Nome do móvel
                pw.Text(
                  "Móvel: $nomeMovel",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                // Cabeçalho da tabela
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColors.grey300,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          "Item",
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          "Medida",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          "Quantidade",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          "Preço",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          "Total",
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),

                if (linhasPdf.isEmpty)
                  pw.Text(
                    "Nenhum item cadastrado para este móvel.",
                    style: const pw.TextStyle(fontSize: 11),
                  )
                else
                  pw.Column(
                    children: linhasPdf.map((linha) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 4,
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                linha.itemName,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                linha.medida,
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                linha.quantidade,
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                linha.preco,
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                linha.total,
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                // ===== RESUMO ABAIXO DA TABELA =====
                pw.SizedBox(height: 12),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Total Bruto: R\$ ${_formatDecimal(totalBruto, dec: 2)}",
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Frete: R\$ ${_formatDecimal(frete, dec: 2)}",
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        "Extra: R\$ ${_formatDecimal(almoco, dec: 2)}",
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        "Mão de Obra Marceneiro: R\$ ${_formatDecimal(maoObra, dec: 2)}",
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        "(%): ${_formatDecimal(lucro, dec: 2)}%",
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        "Total Geral: R\$ ${_formatDecimal(totalGeral, dec: 2)}",
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      // 👇 ADD OBS RIGHT HERE (INSIDE THE SAME COLUMN)
                      if (obsMovel.isNotEmpty || obsMovel.isEmpty) ...[
                        pw.SizedBox(height: 10),
                        pw.Divider(),
                        pw.SizedBox(height: 6),

                        // 🔹 OBS aligned LEFT, text after label
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "Obs: ",
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                obsMovel,
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // 5) Exibe o preview / impressão
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erro ao gerar PDF: $e")),
    );
  }
}

// Atualiza total de um móvel e recalcula o total do orçamento

Future<void> adicionarMovelArmazenadoEmOrcamento({
  required BuildContext context,
  required String clienteId,
  required DocumentSnapshot modeloDoc,
  required int numeroOrcamentoDestino,
}) async {
  final db = FirebaseFirestore.instance;

  final data = modeloDoc.data() as Map<String, dynamic>? ?? {};
  final nomeMovel = data['nome'] as String? ?? "(sem nome)";

  // 1) Criar um novo móvel na coleção principal "moveis"
  final moveisRef = db.collection('moveis');
  final novoMovelRef = moveisRef.doc();

  final novoData = Map<String, dynamic>.from(data);

  // garante que esse móvel agora pertence ao orçamento de destino
  novoData['numeroOrcamento'] = numeroOrcamentoDestino;
  novoData['createdAt'] = FieldValue.serverTimestamp();

  // campos que só faziam sentido no armazenamento
  novoData.remove('numeroOrcamentoOriginal');
  novoData.remove('armazenadoEm');

  await novoMovelRef.set(novoData);

  // 2) Copiar subcoleção "itens" do modelo para o novo móvel
  final itensSnap = await modeloDoc.reference.collection('itens').get();
  for (final item in itensSnap.docs) {
    await novoMovelRef.collection('itens').add(item.data());
  }

  // 3) Remover o modelo da coleção "moveis_armazenados"
  await modeloDoc.reference.delete();
  if (!context.mounted) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Móvel "$nomeMovel" adicionado ao orçamento Nº $numeroOrcamentoDestino e removido dos móveis armazenados.',
      ),
    ),
  );
}

  Future<void> _guardarMovelComoModelo(
  BuildContext context,
  String clienteId,
  DocumentSnapshot movelDoc,
) async {
  final db = FirebaseFirestore.instance;

  final data = movelDoc.data() as Map<String, dynamic>? ?? {};
  final numeroOrcamentoOriginal = data['numeroOrcamento'];
  final nomeMovel = data['nome'] as String? ?? "(sem nome)";

  // coleção onde vamos guardar os móveis "modelo" desse cliente
  final modelosRef = db
      .collection('clientes')
      .doc(clienteId)
      .collection('moveis_armazenados');

  // novo documento de modelo
  final modeloRef = modelosRef.doc();

  final novoData = Map<String, dynamic>.from(data);
  novoData['numeroOrcamentoOriginal'] = numeroOrcamentoOriginal;
  novoData['armazenadoEm'] = FieldValue.serverTimestamp();

  await modeloRef.set(novoData);

  // copiar subcoleção itens
  final itensSnap = await movelDoc.reference.collection('itens').get();
  for (final item in itensSnap.docs) {
    await modeloRef.collection('itens').add(item.data());
  }

  // agora apaga o móvel original (com itens)
  await _apagarMovelComItens(movelDoc);

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Móvel "$nomeMovel" foi guardado e removido do orçamento.'),
    ),
  );
}

Future<void> _duplicarMovel(
  BuildContext context,
  DocumentSnapshot movelDoc,
) async {
  final movelData = movelDoc.data() as Map<String, dynamic>? ?? {};
  final nomeAtual = (movelData['nome'] ?? '').toString();

  final nameCtrl = TextEditingController(text: "$nomeAtual (cópia)");

  final String? novoNome = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Duplicar móvel"),
      content: TextField(
        controller: nameCtrl,
        decoration: const InputDecoration(
          labelText: "Nome do novo móvel",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Cancelar"),
        ),
        TextButton(
          onPressed: () {
            final t = nameCtrl.text.trim();
            Navigator.pop(ctx, t.isEmpty ? null : t);
          },
          child: const Text(
            "Duplicar",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  if (novoNome == null) return;

  try {
    // ✅ SEM INDEX: usa o contador global
    final int novoNumeroMovel = await _gerarProximoNumeroMovelGlobal();

    // cria novo movel
    final newMovelRef = FirebaseFirestore.instance.collection('moveis').doc();

    final newMovelData = Map<String, dynamic>.from(movelData);
    newMovelData['nome'] = novoNome;
    newMovelData['numeroMovel'] = novoNumeroMovel;
    newMovelData['createdAt'] = FieldValue.serverTimestamp();

    // (opcional) se você NÃO quiser copiar o id do orçamento ou outros campos, remova aqui
    // newMovelData.remove('algumCampo');

    await newMovelRef.set(newMovelData);

    // copia itens
    final itensSnap = await movelDoc.reference.collection('itens').get();

    const int chunkSize = 400;
    var batch = FirebaseFirestore.instance.batch();
    int opCount = 0;

    for (final item in itensSnap.docs) {
      final itemData = item.data() as Map<String, dynamic>? ?? {};
      final newItemRef = newMovelRef.collection('itens').doc();

      final newItemData = Map<String, dynamic>.from(itemData);
      newItemData['createdAt'] = FieldValue.serverTimestamp();

      batch.set(newItemRef, newItemData);
      opCount++;

      if (opCount >= chunkSize) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Móvel duplicado: "$novoNome"')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erro ao duplicar móvel: $e")),
    );
  }
}

Future<void> _apagarMovelComItens(DocumentSnapshot movelDoc) async {
  // apaga todos os itens primeiro
  final itensSnap = await movelDoc.reference.collection('itens').get();
  for (final item in itensSnap.docs) {
    await item.reference.delete();
  }
  // depois apaga o móvel
  await movelDoc.reference.delete();
}

Future<void> _mostrarOpcoesMovel(
  BuildContext context,
  DocumentSnapshot movelDoc,
  String nomeMovel,
) async {
  // capture messenger early (so we don't call of(context) after awaits)
  final messenger = ScaffoldMessenger.of(context);

  final escolha = await showDialog<_AcaoMovel>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text('Móvel "$nomeMovel"'),
        content: const Text("O que você deseja fazer com este móvel?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _AcaoMovel.duplicar),
            child: const Text("Duplicar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _AcaoMovel.guardar),
            child: const Text("Guardar e remover"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _AcaoMovel.excluir),
            child: const Text(
              "Excluir definitivamente",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );

  // ✅ after await showDialog, context might be unmounted
  if (!context.mounted) return;

  if (escolha == null) return;

  if (escolha == _AcaoMovel.duplicar) {
    await _duplicarMovel(context, movelDoc);
    if (!context.mounted) return;
  } else if (escolha == _AcaoMovel.guardar) {
    await _guardarMovelComoModelo(context, widget.clienteId, movelDoc);
    if (!context.mounted) return;
  } else if (escolha == _AcaoMovel.excluir) {
    await _apagarMovelComItens(movelDoc);
    if (!context.mounted) return;

    messenger.showSnackBar(
      SnackBar(content: Text('Móvel "$nomeMovel" excluído definitivamente.')),
    );
  }
}

  Future<int> gerarProximoNumeroOrcamento() async {
  final ref = FirebaseFirestore.instance
      .collection('config')
      .doc('contador_orcamentos');

  return FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(ref);

    int atual = 0;
    if (snapshot.exists) {
      atual = (snapshot.data()?['ultimoNumero'] ?? 0) as int;
    }

    final proximo = atual + 1;

    transaction.update(ref, {
      'ultimoNumero': proximo,
    });

    return proximo;
  });
}

Future<int> gerarProximoNumeroOrcamentoGlobal() async {
  final ref = FirebaseFirestore.instance
      .collection('config')
      .doc('contador_orcamentos');

  return FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(ref);

    int atual = 0;
    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      final ultimo = data['ultimoNumero'];
      if (ultimo is int) {
        atual = ultimo;
      } else if (ultimo is num) {
        atual = ultimo.toInt();
      }
    }

    final proximo = atual + 1;

    transaction.set(
      ref,
      {'ultimoNumero': proximo},
      SetOptions(merge: true),
    );

    return proximo;
  });
}

Future<void> criarNovoOrcamento(String clienteId, String clienteNome) async {
  try {
    // 1) Pega o próximo número global de orçamento
    final numeroOrcamento = await gerarProximoNumeroOrcamentoGlobal();

    // 2) Cria o documento do orçamento dentro do cliente
    final novoDoc = await FirebaseFirestore.instance
        .collection('clientes')
        .doc(clienteId)
        .collection('orcamentos')
        .add({
      'numeroOrcamento': numeroOrcamento,
      'createdAt': FieldValue.serverTimestamp(),
      'clienteId': clienteId,
      'clienteNome': clienteNome,
      'pp': null, // 👈 campo que depois a OrcamentoPage vai preencher
    });

    if (!mounted) return;

    // 3) Abre a página do orçamento passando o ID e o número
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrcamentoPage(
          clienteId: clienteId,
          clienteNome: clienteNome,
          orcamentoId: novoDoc.id,
          numeroOrcamento: numeroOrcamento,
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Erro ao criar orçamento: $e"),
      ),
    );
  }
}


  // Larguras
  double larguraCliente = 350;
  double larguraArquiteto = 350;
  double larguraTelefone = 180;

  bool salvandoCliente = false;
  bool salvandoMovel = false;
  bool salvandoOrcamento = false;

  @override
  void initState() {
    super.initState();
    clienteController.text = widget.clienteNome;
    _carregarOrcamento();
    _totaisGeraisPorMovel.clear();
    _moveisJaInicializados.clear();
    _totalOrcamentoNotifier.value = 0.0;
    _carregarCabecalhoOrcamento();
    _moveisStream = FirebaseFirestore.instance
      .collection('moveis')
      .where('numeroOrcamento', isEqualTo: widget.numeroOrcamento)
      .orderBy('numeroMovel')
      .snapshots();
  }

  @override
  void dispose() {
    freteController.dispose();
    extraController.dispose();
    maoDeObraController.dispose();
    percentualController.dispose();
    ppController.dispose();
    clienteController.dispose();
    telefoneClienteController.dispose();
    arquitetoController.dispose();
    _saveTimer?.cancel();
    super.dispose();

        for (final c in _freteControllers.values) {
      c.dispose();
    }
    for (final c in _almocoControllers.values) {
      c.dispose();
    }
    for (final c in _maoObraControllers.values) {
      c.dispose();
    }
    for (final c in _lucroControllers.values) {
      c.dispose();
    }
    for (final c in _obsControllers.values) {
    c.dispose();
  }
    super.dispose();
  }

  // ======================================================
  //          HELPERS GERAIS (FORMATOS / UNIDADES)
  // ======================================================

  String _formatDecimal(num? value, {int dec = 2}) {
    if (value == null) return "-";
    return value.toStringAsFixed(dec);
  }

  String _unitSuffix(String? unitType) {
    switch (unitType) {
      case 'folha':
        return 'm²';
      case 'litro':
        return 'L';
      case 'metro':
        return 'm';
      case 'unidade':
        return 'Und';
      default:
        return '';
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '.'));
    }
    return null;
  }

Widget _buildPrecoCell(
  Map<String, dynamic> itemData, {
  required bool isFolha,
  required bool isColaFormica,
  required bool isColaBranca,
  required bool isUnidade,
  required bool isFita,
  required bool isOutros,
  required bool isPintura,
  required bool isMadeiraMacica,
  required bool isVernizPu,
  required bool isVernizComum,
}) {
  // 👇 Name do item (pode vir de itemName ou name)

  // 👇 Só é "Valor Total" se for unidade + nome "valor total"
  final bool isValorTotal = isUnidade && (itemData['isValorTotal'] == true);

  // FOLHA
  if (isFolha) {
    final precoFolha = _toDouble(itemData['precoFolha']);
    if (precoFolha == null) {
      return const Text(
        "-",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      );
    }
    return Text(
      "R\$ ${_formatDecimal(precoFolha, dec: 2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
    );
  }

  // COLA FORMICA → preço por L
  if (isColaFormica) {
    final precoL = _toDouble(itemData['precoL']);
    if (precoL == null) {
      return const Text(
        "-",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      );
    }
    return Text(
      "R\$ ${_formatDecimal(precoL, dec: 2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
    );
  }

  // COLA BRANCA → preço por L
  if (isColaBranca) {
    final precoL = _toDouble(itemData['precoL']);
    if (precoL == null) {
      return const Text(
        "-",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      );
    }
    return Text(
      "R\$ ${_formatDecimal(precoL, dec: 2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
    );
  }

  // FITA → preço por metro
  if (isFita || isOutros) {
    final precoMetro = _toDouble(itemData['precoMetro']);
    if (precoMetro == null) {
      return const Text(
        "-",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      );
    }
    return Text(
      "R\$ ${_formatDecimal(precoMetro, dec: 2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
    );
  }

  // 🔥 PINTURA + VERNIZ PU / COMUM → preço por m²
  if (isPintura || isVernizPu || isVernizComum) {
    final precoM2 = _toDouble(itemData['precoM2']);
    if (precoM2 == null) {
      return const Text(
        "-",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      );
    }
    return Text(
      "R\$ ${_formatDecimal(precoM2, dec: 2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
    );
  }

  // MADEIRA MACIÇA → preço por m³
  if (isMadeiraMacica) {
    final precoM3 = _toDouble(itemData['precoM3']);
    if (precoM3 == null) {
      return const Text(
        "-",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      );
    }
    return Text(
      "R\$ ${_formatDecimal(precoM3, dec: 2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
    );
  }

  // ⭐ CASO ESPECIAL: "Valor Total" (unidade) → usa precoUnd salvo no móvel
  if (isValorTotal) {
    final precoUnd = _toDouble(itemData['precoUnd']);
    if (precoUnd == null) {
      return const Text(
        "-",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      );
    }
    return Text(
      "R\$ ${_formatDecimal(precoUnd, dec: 2)}",
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
    );
  }

  // fallback para outros (unidade normal etc.)
  final precoUnidade =
      _toDouble(itemData['precoUnidade'] ?? itemData['precoUnd']);
  if (precoUnidade == null) {
    return const Text(
      "-",
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13),
    );
  }

  return Text(
    "R\$ ${_formatDecimal(precoUnidade, dec: 2)}",
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 13),
  );
}

Future<void> _editObsDialog(DocumentSnapshot movelDoc) async {
  final movelData = movelDoc.data() as Map<String, dynamic>? ?? {};
  final String obsAtual = (movelData['obs'] ?? '').toString();

  final ctrl = _getOrCreateObsController(movelDoc.id, initial: obsAtual);

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("Obs"),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: "Escreva qualquer observação deste móvel...",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              final texto = ctrl.text.trim();

              try {
                await movelDoc.reference.update({
                  'obs': texto,
                  'obsUpdatedAt': FieldValue.serverTimestamp(),
                });

                // ✅ Fecha o dialog assim que salvar
                if (ctx.mounted) Navigator.pop(ctx);

                // ✅ SnackBar usando o context da página (se ainda existir)
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Obs salva.")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Erro ao salvar Obs: $e")),
                  );
                }
              }
            },
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}

  // ======================================================
  //          CARREGAR / SALVAR ORÇAMENTO (HEADER)
  // ======================================================

  Future<void> _carregarOrcamento() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('clientes')
          .doc(widget.clienteId)
          .collection('orcamentos')
          .doc(widget.orcamentoId);

      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        ppController.text = data['pp']?.toString() ?? '';
        clienteController.text = data['clienteNome'] ?? widget.clienteNome;
        telefoneClienteController.text = data['telefone'] ?? '';
        arquitetoController.text = data['arquiteto'] ?? '';
      }
    } catch (e) {
      debugPrint('Erro ao carregar orçamento: $e');
    }
  }

  // ======================================================
  //                    ADICIONAR MÓVEL
  // ======================================================

Future<void> _showAddMovelDialog(BuildContext context) async {
  final TextEditingController controller = TextEditingController();

  final String? nomeMovel = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("Novo Móvel"),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: "Nome do móvel",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              final txt = controller.text.trim();
              if (txt.isEmpty) {
                Navigator.pop(ctx, null);
              } else {
                Navigator.pop(ctx, txt);
              }
            },
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );

  if (nomeMovel == null || nomeMovel.isEmpty) return;

  try {
    // 👉 aqui usamos o contador GLOBAL
    final int numeroMovel = await _gerarProximoNumeroMovelGlobal();

    await FirebaseFirestore.instance.collection('moveis').add({
      'clienteId': widget.clienteId,
      'orcamentoId': widget.orcamentoId,
      'nome': nomeMovel,
      'numeroOrcamento': widget.numeroOrcamento, // se ainda usa pra filtrar
      'numeroMovel': numeroMovel,                // AGORA É GLOBAL
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Móvel #$numeroMovel "$nomeMovel" adicionado.'),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao salvar móvel: $e')),
    );
  }
}

  // ======================================================
  //       ADICIONAR ITEM (VINDO DA COLEÇÃO items) A UM MÓVEL
  // ======================================================

  Future<void> _showAddItemMovelDialog(
  BuildContext context,
  DocumentSnapshot movelDoc,
) async {
  final nomeMovel =
      (movelDoc.data() as Map<String, dynamic>?)?['nome'] ?? '';
  String filtro = "";

  final DocumentSnapshot? itemEscolhido =
      await showDialog<DocumentSnapshot>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final itemsQuery =
              FirebaseFirestore.instance.collection('items');

          return AlertDialog(
            title: Text('Adicionar item para "$nomeMovel"'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Buscar item",
                      hintText: "Digite parte do nome...",
                    ),
                    onChanged: (value) {
                      setStateDialog(() {
                        filtro = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 260,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: itemsQuery.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            "Erro ao carregar itens: ${snapshot.error}",
                            style: const TextStyle(color: Colors.red),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData ||
                            snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              "Nenhum item cadastrado ainda.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        final todos = snapshot.data!.docs;
                        final filtrados = todos.where((doc) {
                          final data =
                              doc.data() as Map<String, dynamic>?;
                          final nome =
                              (data?['name'] ?? '') as String;
                          if (filtro.isEmpty) return true;
                          return nome.toLowerCase().contains(filtro);
                        }).toList()
                          ..sort((a, b) {
                            final da =
                                (a.data() as Map<String, dynamic>? ?? {});
                            final db =
                                (b.data() as Map<String, dynamic>? ?? {});
                            final na = (da['name'] ?? '') as String;
                            final nb = (db['name'] ?? '') as String;
                            return na
                                .toLowerCase()
                                .compareTo(nb.toLowerCase());
                          });

                        if (filtrados.isEmpty) {
                          return const Center(
                            child: Text(
                              "Nenhum item encontrado.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filtrados.length,
                          itemBuilder: (context, index) {
                            final doc = filtrados[index];
                            final data =
                                doc.data() as Map<String, dynamic>? ?? {};
                            final nome = data['name'] as String? ??
                                "(sem nome)";

                            return ListTile(
                              title: Text(nome),
                              onTap: () {
                                Navigator.pop(ctx, doc);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
            ],
          );
        },
      );
    },
  );

  if (itemEscolhido == null) return;

  try {
    final dataItem =
        itemEscolhido.data() as Map<String, dynamic>? ?? {};
    final itemName = dataItem['name'] as String? ?? "(sem nome)";
    final unitType = dataItem['unitType']; // 'folha', 'litro', etc
    final subcategory = dataItem['subcategory']; // ex: 'tintas', 'colas'

    // copiando informações importantes do item "original" para o item do móvel
    final precoFolha = dataItem['precoFolha'];
    final areaFolha = dataItem['areaFolha'];
    final taxaPerca = dataItem['taxaPerca'];
    final precoUnidade = dataItem['precoUnidade'];
    final metragem = dataItem['metragem'];
    final precoMetro = dataItem['precoMetro'];

    // 🔹 Cola: preço/L e L/m² (se existirem no item original)
    final precoM2 = dataItem['precoM2'];
    final precoL = dataItem['precoL'];
    final lm2Mdf = dataItem['lm2Mdf'];
    final lm2Formica = dataItem['lm2Formica'];
    final hasPrecoL = dataItem['hasPrecoL'];
    final hasLm2 = dataItem['hasLm2'];
    final usaLm2Separado = dataItem['usaLm2Separado'];
    final precoM3 = dataItem['precoM3'];

final bool isValorTotalItem =
    unitType == 'unidade' &&
    itemName.trim().toLowerCase() == 'valor total';

await movelDoc.reference.collection('itens').add({
  'itemId': itemEscolhido.id,
  'itemName': itemName,
  'unitType': unitType,
  'subcategory': subcategory,

  // ✅ ONLY "Valor Total" gets the flag
  'isValorTotal': isValorTotalItem,

  'linhas': [],
  'precoFolha': precoFolha,
  'areaFolha': areaFolha,
  'taxaPerca': taxaPerca,
  'precoUnidade': precoUnidade,
  'precoL': precoL,
  'lm2Mdf': lm2Mdf,
  'lm2Formica': lm2Formica,
  'usaLm2Separado': usaLm2Separado,
  'hasPrecoL': hasPrecoL,
  'hasLm2': hasLm2,
  'precoM2': precoM2,
  'metragem': metragem,
  'precoMetro': precoMetro,
  'precoM3': precoM3,
  'createdAt': FieldValue.serverTimestamp(),

  // (optional defaults for Valor Total)
  if (isValorTotalItem) ...{
    'quantidadeUnd': 1,
    'precoUnd': 0,
    'medidaValorTotal': 'Und',
  },
});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item "$itemName" adicionado em "$nomeMovel".'),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erro ao salvar item: $e")),
    );
  }
}

  // ======================================================
  //  EDITAR MEDIDAS MADEIRA
  // ======================================================
    Future<void> _editMadeiraMacicaDialog(
    DocumentSnapshot movelDoc, // igual assinatura da folha, mesmo sem usar
    DocumentSnapshot itemDoc,
    String itemName,
  ) async {
    final data = itemDoc.data() as Map<String, dynamic>? ?? {};
    // usamos um campo separado pra madeira maciça
    final linhasData = (data['madeiraLinhas'] as List?) ?? [];
    bool vernizPU = data['vernizPU'] == true;
    bool vernizComum = data['vernizComum'] == true;


    final List<LinhaMadeira> linhas = [];

    if (linhasData.isNotEmpty) {
      for (final l in linhasData) {
        if (l is Map<String, dynamic>) {
          linhas.add(
            LinhaMadeira(
              qtd: l['quantidade']?.toString(),
              comp: l['comprimento']?.toString(),
              larg: l['largura']?.toString(),
              alt: l['altura']?.toString(),
              lados: l['lados']?.toString(),
            ),
          );
        }
      }
    }

    if (linhas.isEmpty) {
      linhas.add(LinhaMadeira());
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Posicao? findPosicaoAtual() {
              final current = FocusManager.instance.primaryFocus;
              if (current == null) return null;

              for (var i = 0; i < linhas.length; i++) {
                final l = linhas[i];
                if (current == l.qtdFocus) return Posicao(i, 0);
                if (current == l.compFocus) return Posicao(i, 1);
                if (current == l.largFocus) return Posicao(i, 2);
                if (current == l.altFocus) return Posicao(i, 3);
              }
              return null;
            }

            void moveFocus({
              int deltaLinha = 0,
              int deltaColuna = 0,
              bool criarSeDownNoFinal = false,
            }) {
              final pos = findPosicaoAtual();
              if (pos == null) return;

              int linha = pos.linha;
              int coluna = pos.coluna;

              // mover coluna (0..3 → qtd, comp, larg, alt)
              if (deltaColuna != 0) {
                final newCol = coluna + deltaColuna;
                if (newCol < 0 || newCol > 3) {
                  return;
                }
                coluna = newCol;
              }

              // mover linha
              if (deltaLinha != 0) {
                final newLinha = linha + deltaLinha;
                if (newLinha < 0) return;

                if (newLinha >= linhas.length) {
                  // ↓ na última linha: cria nova
                  if (criarSeDownNoFinal && deltaLinha > 0) {
                    setStateDialog(() {
                      linhas.add(LinhaMadeira());
                    });
                    linha = linhas.length - 1;
                    coluna = 0; // começa em Quantidade
                  } else {
                    return;
                  }
                } else {
                  linha = newLinha;
                }
              }

              final l = linhas[linha];
              FocusNode node;
              if (coluna == 0) {
                node = l.qtdFocus;
              } else if (coluna == 1) {
                node = l.compFocus;
              } else if (coluna == 2) {
                node = l.largFocus;
              } else {
                node = l.altFocus;
              }

              Future.microtask(() {
                node.requestFocus();
              });
            }

            Future<void> salvar() async {
              final lista = <Map<String, dynamic>>[];

              for (final l in linhas) {
                final m = l.toMap();

                // pelo menos um campo preenchido
                final temAlgum = m.values.any(
                  (v) => v != null && v.toString().trim().isNotEmpty,
                );

                if (temAlgum) {
                  lista.add(m);
                }
              }

              try {
                await itemDoc.reference.update({
                  'madeiraLinhas': lista,
                  'vernizPU': vernizPU,
                  'vernizComum': vernizComum,
                });

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Medidas de Madeira Maciça salvas."),
                  ),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Erro ao salvar medidas de Madeira Maciça: $e",
                    ),
                  ),
                );
              }
            }

            void addLinha() {
              setStateDialog(() {
                linhas.add(LinhaMadeira());
              });
            }

            return Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                    const MoveLeftIntent(),
                LogicalKeySet(LogicalKeyboardKey.arrowRight):
                    const MoveRightIntent(),
                LogicalKeySet(LogicalKeyboardKey.arrowUp):
                    const MoveUpIntent(),
                LogicalKeySet(LogicalKeyboardKey.arrowDown):
                    const MoveDownIntent(),
                LogicalKeySet(LogicalKeyboardKey.enter):
                    const SaveIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  MoveLeftIntent: CallbackAction<MoveLeftIntent>(
                    onInvoke: (intent) {
                      moveFocus(deltaColuna: -1);
                      return null;
                    },
                  ),
                  MoveRightIntent: CallbackAction<MoveRightIntent>(
                    onInvoke: (intent) {
                      moveFocus(deltaColuna: 1);
                      return null;
                    },
                  ),
                  MoveUpIntent: CallbackAction<MoveUpIntent>(
                    onInvoke: (intent) {
                      moveFocus(deltaLinha: -1);
                      return null;
                    },
                  ),
                  MoveDownIntent: CallbackAction<MoveDownIntent>(
                    onInvoke: (intent) {
                      moveFocus(
                        deltaLinha: 1,
                        criarSeDownNoFinal: true,
                      );
                      return null;
                    },
                  ),
                  SaveIntent: CallbackAction<SaveIntent>(
                    onInvoke: (intent) {
                      salvar();
                      return null;
                    },
                  ),
                },
                child: FocusScope(
                  autofocus: true,
                  child: AlertDialog(
                    title: Text('Madeira Maciça - $itemName'),
                    content: SizedBox(
                      width: 600,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Use as setas para navegar. ↓ na última linha adiciona nova linha. ENTER salva.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  dense: true,
                                  title: const Text("Verniz PU"),
                                  value: vernizPU,
                                  onChanged: (v) {
                                    setStateDialog(() {
                                      vernizPU = v ?? false;
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  dense: true,
                                  title: const Text("Verniz Comum"),
                                  value: vernizComum,
                                  onChanged: (v) {
                                    setStateDialog(() {
                                      vernizComum = v ?? false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 260,
                            child: ListView.builder(
                              itemCount: linhas.length,
                              itemBuilder: (context, index) {
                                final linha = linhas[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6.0),
                                  child: Row(
                                    children: [
                                      // Qtd
                                      SizedBox(
                                        width: 70,
                                        height: 34,
                                        child: TextField(
                                          controller:
                                              linha.qtdController,
                                          focusNode: linha.qtdFocus,
                                          keyboardType:
                                              TextInputType.number,
                                          decoration:
                                              const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: 8,
                                            ),
                                            border:
                                                OutlineInputBorder(),
                                            labelText: "Qtd",
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Comp
                                      SizedBox(
                                        width: 100,
                                        height: 34,
                                        child: TextField(
                                          controller:
                                              linha.compController,
                                          focusNode: linha.compFocus,
                                          keyboardType:
                                              const TextInputType
                                                      .numberWithOptions(
                                                  decimal: true),
                                          decoration:
                                              const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: 8,
                                            ),
                                            border:
                                                OutlineInputBorder(),
                                            labelText: "Comp",
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Larg
                                      SizedBox(
                                        width: 100,
                                        height: 34,
                                        child: TextField(
                                          controller:
                                              linha.largController,
                                          focusNode: linha.largFocus,
                                          keyboardType:
                                              const TextInputType
                                                      .numberWithOptions(
                                                  decimal: true),
                                          decoration:
                                              const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: 8,
                                            ),
                                            border:
                                                OutlineInputBorder(),
                                            labelText: "Larg",
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Alt
                                      SizedBox(
                                        width: 100,
                                        height: 34,
                                        child: TextField(
                                          controller:
                                              linha.altController,
                                          focusNode: linha.altFocus,
                                          keyboardType:
                                              const TextInputType
                                                      .numberWithOptions(
                                                  decimal: true),
                                          decoration:
                                              const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: 8,
                                            ),
                                            border:
                                                OutlineInputBorder(),
                                            labelText: "Alt",
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Lados (Dropdown 3/4/5)
                                      SizedBox(
                                        width: 90,
                                        height: 34,
                                        child: DropdownButtonFormField<
                                            String>(
                                          initialValue: linha.lados,
                                          isDense: true,
                                          decoration:
                                              const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: 8,
                                            ),
                                            border:
                                                OutlineInputBorder(),
                                            labelText: "Lados",
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: '3',
                                              child: Text('3'),
                                            ),
                                            DropdownMenuItem(
                                              value: '4',
                                              child: Text('4'),
                                            ),
                                            DropdownMenuItem(
                                              value: '5',
                                              child: Text('5'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setStateDialog(() {
                                              linha.lados =
                                                  value ?? '4';
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      if (linhas.length > 1)
                                        IconButton(
                                          onPressed: () {
                                            setStateDialog(() {
                                              linhas.removeAt(index);
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          tooltip: "Remover linha",
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: addLinha,
                              icon: const Icon(Icons.add),
                              label: const Text("Adicionar linha"),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancelar"),
                      ),
                      TextButton(
                        onPressed: salvar,
                        child: const Text(
                          "Salvar",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

// ======================================================
//      EDITAR MEDIDAS DE ITEM DE FOLHA  (com Qtd Folhas)
//      Fórmula da área: qtdFolhas * qtd * (comp*larg/10000)
// ======================================================

Future<void> _editFolhaMedidasDialog(
  DocumentSnapshot movelDoc,
  DocumentSnapshot itemDoc,
  String itemName,
) async {
  final data = itemDoc.data() as Map<String, dynamic>? ?? {};
  final linhasData = (data['linhas'] as List?) ?? [];

  final List<LinhaFolha> linhas = [];

  // Carrega linhas salvas
  if (linhasData.isNotEmpty) {
    for (final l in linhasData) {
      if (l is Map<String, dynamic>) {
        linhas.add(
          LinhaFolha(
            folhas: l['qtdFolhas']?.toString(), // ✅ NOVO
            qtd: l['quantidade']?.toString(),
            comp: l['comprimento']?.toString(),
            larg: l['largura']?.toString(),
          ),
        );
      }
    }
  }

  if (linhas.isEmpty) {
    linhas.add(LinhaFolha());
  }

  await showDialog(
    context: context,
    builder: (ctx) {
      bool initializedFocus = false;

      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          // Foca na 1ª célula (Folhas)
          if (!initializedFocus && linhas.isNotEmpty) {
            initializedFocus = true;
            Future.microtask(() {
              linhas.first.qtdFocus.requestFocus(); // ✅ NOVO
            });
          }

          void addLinha() {
            setStateDialog(() {
              linhas.add(LinhaFolha());
            });
            Future.microtask(() {
              linhas.last.qtdFocus.requestFocus(); // ✅ NOVO
            });
          }

          Future<void> salvar() async {
            final lista = <Map<String, dynamic>>[];

            for (final l in linhas) {
              final map = l.toMap();

              final allEmpty =
                  (map['qtdFolhas'] as String).isEmpty && // ✅ NOVO
                  (map['quantidade'] as String).isEmpty &&
                  (map['comprimento'] as String).isEmpty &&
                  (map['largura'] as String).isEmpty;

              if (!allEmpty) {
                lista.add(map);
              }
            }

            try {
              // Capture UI helpers BEFORE awaiting (avoids context across async gap)
              final messenger = ScaffoldMessenger.of(context);

              await itemDoc.reference.update({
                'linhas': lista,
              });

              // Guard the BuildContext you are using
              if (!context.mounted) return;

              messenger.showSnackBar(
                SnackBar(
                  content: Text('Medidas salvas para "$itemName".'),
                ),
              );

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            } catch (e) {
              if (!mounted) return;

              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                SnackBar(
                  content: Text("Erro ao salvar medidas: $e"),
                ),
              );
            }
          }

          Posicao? findPosicaoAtual() {
            final current = FocusManager.instance.primaryFocus;
            if (current == null) return null;

            for (var i = 0; i < linhas.length; i++) {
              final l = linhas[i];
              if (current == l.qtdFocus) return Posicao(i, colQtd);
              if (current == l.compFocus) return Posicao(i, colComp);
              if (current == l.largFocus) return Posicao(i, colLarg);
              if (current == l.folhasFocus) return Posicao(i, colFolhas);
            }
            return null;
          }


          void moveFocus({
            int deltaLinha = 0,
            int deltaColuna = 0,
            bool criarSeDownNoFinal = false,
          }) {
            final pos = findPosicaoAtual();
            if (pos == null) return;

            int linha = pos.linha;
            int coluna = pos.coluna;

            // mover coluna (0..3)
            if (deltaColuna != 0) {
              final newCol = coluna + deltaColuna;
              if (newCol < 0 || newCol > colMax) return;
              coluna = newCol;
            }

            // mover linha
            if (deltaLinha != 0) {
              final newLinha = linha + deltaLinha;
              if (newLinha < 0) return;

              if (newLinha >= linhas.length) {
                if (criarSeDownNoFinal && deltaLinha > 0) {
                  addLinha();
                  linha = linhas.length - 1;
                } else {
                  return;
                }
              } else {
                linha = newLinha;
              }

              // ✅ ALWAYS start in first column when moving lines
              coluna = 0; // 0 = qtdFocus in your mapping
            }

            final l = linhas[linha];
            late FocusNode node;

            if (coluna == colQtd) {
              node = l.qtdFocus;
            } else if (coluna == colComp) {
              node = l.compFocus;
            } else if (coluna == colLarg) {
              node = l.largFocus;
            } else {
              node = l.folhasFocus;
            }

            Future.microtask(() {
              node.requestFocus();
            });
          }

          return Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                  const MoveLeftIntent(),
              LogicalKeySet(LogicalKeyboardKey.arrowRight):
                  const MoveRightIntent(),
              LogicalKeySet(LogicalKeyboardKey.arrowUp):
                  const MoveUpIntent(),
              LogicalKeySet(LogicalKeyboardKey.arrowDown):
                  const MoveDownIntent(),
              LogicalKeySet(LogicalKeyboardKey.enter):
                  const SaveIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                MoveLeftIntent: CallbackAction<MoveLeftIntent>(
                  onInvoke: (intent) {
                    moveFocus(deltaColuna: -1);
                    return null;
                  },
                ),
                MoveRightIntent: CallbackAction<MoveRightIntent>(
                  onInvoke: (intent) {
                    moveFocus(deltaColuna: 1);
                    return null;
                  },
                ),
                MoveUpIntent: CallbackAction<MoveUpIntent>(
                  onInvoke: (intent) {
                    moveFocus(deltaLinha: -1);
                    return null;
                  },
                ),
                MoveDownIntent: CallbackAction<MoveDownIntent>(
                  onInvoke: (intent) {
                    moveFocus(
                      deltaLinha: 1,
                      criarSeDownNoFinal: true,
                    );
                    return null;
                  },
                ),
                SaveIntent: CallbackAction<SaveIntent>(
                  onInvoke: (intent) {
                    salvar();
                    return null;
                  },
                ),
              },
              child: FocusScope(
                autofocus: true,
                child: AlertDialog(
                  title: Text('Medidas - $itemName'),
                  content: SizedBox(
                    width: 590,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Use as setas para navegar. ↓ na última linha adiciona nova linha. ENTER salva.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 260,
                          child: ListView.builder(
                            itemCount: linhas.length,
                            itemBuilder: (context, index) {
                              final linha = linhas[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: [

                                    // Qtd
                                    SizedBox(
                                      width: 80,
                                      height: 34,
                                      child: TextField(
                                        controller: linha.qtdController,
                                        focusNode: linha.qtdFocus,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 8,
                                          ),
                                          border: OutlineInputBorder(),
                                          labelText: "Qtd",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Comp
                                    SizedBox(
                                      width: 120,
                                      height: 34,
                                      child: TextField(
                                        controller: linha.compController,
                                        focusNode: linha.compFocus,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 8,
                                          ),
                                          border: OutlineInputBorder(),
                                          labelText: "Comp",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Larg
                                    SizedBox(
                                      width: 120,
                                      height: 34,
                                      child: TextField(
                                        controller: linha.largController,
                                        focusNode: linha.largFocus,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 8,
                                          ),
                                          border: OutlineInputBorder(),
                                          labelText: "Larg",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    // ✅ NOVO: Qtd Folhas
                                    SizedBox(
                                      width: 90,
                                      height: 34,
                                      child: TextField(
                                        controller: linha.folhasController,
                                        focusNode: linha.folhasFocus,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 8,
                                          ),
                                          border: OutlineInputBorder(),
                                          labelText: "Folhas",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    if (linhas.length > 1)
                                      IconButton(
                                        onPressed: () {
                                          setStateDialog(() {
                                            linhas.removeAt(index);
                                          });
                                        },
                                        icon: const Icon(Icons.close, size: 18),
                                        tooltip: "Remover linha",
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: addLinha,
                            icon: const Icon(Icons.add),
                            label: const Text("Adicionar linha"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancelar"),
                    ),
                    TextButton(
                      onPressed: salvar,
                      child: const Text(
                        "Salvar",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  // ======================================================
  //      EDITAR LITROS DE COLA BRANCA (APENAS 1 VALOR L)
  // ======================================================

  Future<void> _editColaBrancaDialog(
    DocumentSnapshot itemDoc,
    String itemName,
  ) async {
    final data = itemDoc.data() as Map<String, dynamic>? ?? {};
    final litrosExistente = data['litros'] as num?;

    final controller = TextEditingController(
      text: litrosExistente != null ? litrosExistente.toString() : "",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Litros - $itemName'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Quantidade em Litros (L)",
              hintText: "Ex: 2.5",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              final txt = controller.text.trim();
              final valor = double.tryParse(txt.replaceAll(',', '.'));

              try {
                await itemDoc.reference.update({
                  'litros': valor,
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Litros de "$itemName" atualizados para ${valor ?? "-"} L'),
                    ),
                  );
                }
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erro ao salvar litros: $e"),
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

double _calcularVolumeM3Madeira(DocumentSnapshot itemDoc) {
  final data = itemDoc.data() as Map<String, dynamic>? ?? {};
  final linhas = (data['madeiraLinhas'] as List?) ?? [];

  double total = 0;

  for (final l in linhas) {
    if (l is! Map<String, dynamic>) continue;

    final qtd   = _toDouble(l['quantidade']) ?? 0;
    final comp  = _toDouble(l['comprimento']) ?? 0;
    final larg  = _toDouble(l['largura']) ?? 0;
    final alt   = _toDouble(l['altura']) ?? 0;

    if (qtd <= 0 || comp <= 0 || larg <= 0 || alt <= 0) continue;

    // assumindo tudo em metros → volume em m³
    final volume = qtd * comp * larg * alt;
    total += volume;
  }

  return total;
}

double _calcularAreaM2VernizParaMovel(
  List<DocumentSnapshot> itensDocs, {
  required bool paraVernizPu,
}) {
  double soma = 0;

  for (final doc in itensDocs) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final unitType = data['unitType'] as String? ?? '';

    // Só madeira maciça entra aqui
    if (unitType != 'madeiraMacica') continue;

    // Flags salvas no edit dialog
    final bool usaPu = data['vernizPU'] == true;
    final bool usaComum = data['vernizComum'] == true;

    // Se estamos calculando para PU, só conta quem marcou PU
    if (paraVernizPu && !usaPu) continue;

    // Se estamos calculando para Comum, só conta quem marcou Comum
    if (!paraVernizPu && !usaComum) continue;

    final linhas = (data['madeiraLinhas'] as List?) ?? [];

    for (final l in linhas) {
      if (l is! Map<String, dynamic>) continue;

      final double? qtd = _toDouble(l['quantidade']);
      final double? comp = _toDouble(l['comprimento']);
      final double? larg = _toDouble(l['largura']);
      final double? alt = _toDouble(l['altura']);
      final String ladosStr = (l['lados']?.toString() ?? '4').trim();

      if (qtd == null || comp == null || larg == null || alt == null) {
        continue;
      }

      double areaCm2 = 0;

      if (ladosStr == '3') {
        // 3 lados: ((((2 * alt) + larg) * comp) * quantidade)
        areaCm2 = (((2 * alt) + larg) * comp) * qtd;
      } else if (ladosStr == '4') {
        // 4 lados: ((2 * larg + 2 * alt) * comp) * quantidade
        areaCm2 = ((2 * larg + 2 * alt) * comp) * qtd;
      } else if (ladosStr == '5') {
        // 5 lados: (((larg * alt) * 2) + (comp * larg) + ((comp * alt) * 2)) * quantidade
        areaCm2 =
            (((larg * alt) * 2) + (comp * larg) + ((comp * alt) * 2)) * qtd;
      } else {
        // se por algum motivo vier outro valor, ignora
        continue;
      }

      // cm² → m²  (se suas medidas já forem em m, tira o / 10000)
      final areaM2 = areaCm2 / 10000.0;
      if (areaM2 > 0) {
        soma += areaM2;
      }
    }
  }

  return soma;
}

double _calcularLitrosColaFormicaParaItem(
  DocumentSnapshot itemMovelDoc,
  double lm2Mdf,
  double lm2Formica,
) {
  final data = itemMovelDoc.data() as Map<String, dynamic>? ?? {};

  // tudo minúsculo pra não dar erro por maiúscula
  final unitType = (data['unitType'] as String?)?.toLowerCase() ?? '';
  final sub = (data['subcategory'] as String?)?.toLowerCase() ?? '';

  // não confiar demais no unitType, só evitar "litro"
  final bool isLitro = unitType == 'litro';

  // identificadores por subcategoria, aceitando coisas como "mdf branco"
  final bool isMdf     = sub.contains('mdf');
  final bool isFormica = sub.contains('formica');
  final bool isLamina  = sub.contains('lamina');
  final bool isManta   = sub.contains('manta');
  final bool isFita    = unitType == 'metro' && sub.contains('fita');
  final bool isOutros  = unitType == 'metro' && sub.contains('outros');

  const double litrosPorMetroFita = 1.0;

  // =============== FOLHAS (MDF / FORMICA / LÂMINA / MANTA) ===============
  // qualquer coisa que não seja "litro" nem "metro", vamos tentar tratar como folha com área
  final bool usaArea = !isLitro && !isFita || !isOutros && (isMdf || isFormica || isLamina || isManta);

  if (usaArea) {
    final double areaM2 = _calcularAreaM2DeFolha(itemMovelDoc);
    if (areaM2 <= 0) return 0;

    // Lâmina ou Manta → 1L por m²
    if (isLamina || isManta) {
      return areaM2;
    }

    // MDF → usa lm2Mdf
    if (isMdf) {
      if (lm2Mdf <= 0) return 0;
      return areaM2 * lm2Mdf;
    }

    // Formica → usa lm2Formica
    if (isFormica) {
      if (lm2Formica <= 0) return 0;
      return areaM2 * lm2Formica;
    }

    return 0;
  }

  // =============== FITA (metro) ===============
  if (isFita || isOutros) {
    final metrosFita = _toDouble(data['metrosFita']);
    final quantidadeUsada = _toDouble(data['quantidadeUsada']);
    final metragemItem = _toDouble(data['metragem']);

    final metros = metrosFita ?? quantidadeUsada ?? metragemItem ?? 0;

    if (metros <= 0) return 0;

    return metros * litrosPorMetroFita * 0.05; // 1 m -> 1 L
  }

  // outros tipos não entram na cola
  return 0;
}

double _calcularAreaM2TotalLaminas(List<DocumentSnapshot> itensDocs) {
  double soma = 0;

  for (final doc in itensDocs) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final unitType = data['unitType'] as String? ?? '';
    final sub = (data['subcategory'] as String?)?.toLowerCase() ?? '';

    // Folha de LÂMINA
    if (unitType == 'folha' && sub.contains('lamina')) {
      final area = _calcularAreaM2DeFolha(doc);
      if (area > 0) {
        soma += area;
      }
    }
  }

  return soma;
}

double _calcularAreaM2DeFolha(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>? ?? {};
  final linhas = (data['linhas'] as List?) ?? [];

  final double areaFolha = _toDouble(data['areaFolha']) ?? 0; // m² por folha
  double somaM2 = 0;

  for (final raw in linhas) {
    if (raw is! Map<String, dynamic>) continue;

    // ✅ 1) Se digitou qtdFolhas, usa ela
    final qFolhas = _toDouble(raw['qtdFolhas']);
    if (qFolhas != null && qFolhas > 0 && areaFolha > 0) {
      somaM2 += qFolhas * areaFolha;
      continue;
    }

    // ✅ 2) Senão, cai no modo normal (qtd * comp * larg)
    final q = _toDouble(raw['quantidade']);
    final c = _toDouble(raw['comprimento']);
    final g = _toDouble(raw['largura']);
    if (q != null && c != null && g != null) {
      somaM2 += q * (c * g / 10000.0);
    }
  }

  return somaM2;
}

Future<void> _ensureVernizesParaMadeiraMacica(
  DocumentSnapshot movelDoc,
  List<QueryDocumentSnapshot> itensDocs,
) async {
  bool precisaPu = false;
  bool precisaNormal = false;

  // 1) Ler as MADEIRAS MACIÇAS deste móvel
  for (final d in itensDocs) {
    final data = d.data() as Map<String, dynamic>? ?? {};
    final unitType = (data['unitType'] as String?)?.toLowerCase() ?? '';

    if (unitType == 'madeiramacica') {
      // ⚠️ Usa exatamente os campos que você salva no diálogo:
      if (data['vernizPU'] == true) {
        precisaPu = true;
      }
      if (data['vernizComum'] == true) {
        precisaNormal = true;
      }
    }
  }

  // Se nenhuma madeira maciça pede verniz, não faz nada
  if (!precisaPu && !precisaNormal) return;

  // 2) Garantir Verniz PU
  if (precisaPu && !_criandoVernizPu) {
    _criandoVernizPu = true;
    try {
      // Ver se já existe Verniz PU neste móvel
      final existingPu = await movelDoc.reference
          .collection('itens')
          .where('unitType', isEqualTo: 'litro')
          .where('itemName', isEqualTo: 'Verniz PU')
          .limit(1)
          .get();

      if (existingPu.docs.isEmpty) {
        // Buscar o item global "Verniz PU" em items
        final queryPu = await FirebaseFirestore.instance
            .collection('items')
            .where('unitType', isEqualTo: 'litro')
            .where('name', isEqualTo: 'Verniz PU')
            .limit(1)
            .get();

        if (queryPu.docs.isNotEmpty) {
          final itemVernizPu = queryPu.docs.first;
          final dataItem = itemVernizPu.data() as Map<String, dynamic>? ?? {};

          await movelDoc.reference.collection('itens').add({
            'itemId': itemVernizPu.id,
            'itemName': dataItem['name'] ?? 'Verniz PU',
            'unitType': dataItem['unitType'] ?? 'litro',
            'subcategory': dataItem['subcategory'],
            'precoM2': dataItem['precoM2'],
            'hasPrecoM2': dataItem['hasPrecoM2'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } finally {
      _criandoVernizPu = false;
    }
  }

  // 3) Garantir VERNIZ COMUM
  if (precisaNormal && !_criandoVernizComum) {
    _criandoVernizComum = true;
    try {
      // Ver se já existe Verniz Comum neste móvel
      final existingNormal = await movelDoc.reference
          .collection('itens')
          .where('unitType', isEqualTo: 'litro')
          .where('itemName', isEqualTo: 'Verniz Comum')
          .limit(1)
          .get();

      if (existingNormal.docs.isEmpty) {
        // Buscar item global "Verniz Comum" em items
        final queryNormal = await FirebaseFirestore.instance
            .collection('items')
            .where('unitType', isEqualTo: 'litro')
            .where('name', isEqualTo: 'Verniz Comum')
            .limit(1)
            .get();

        if (queryNormal.docs.isNotEmpty) {
          final itemVernizComum = queryNormal.docs.first;
          final dataItem =
              itemVernizComum.data() as Map<String, dynamic>? ?? {};

          await movelDoc.reference.collection('itens').add({
            'itemId': itemVernizComum.id,
            'itemName': dataItem['name'] ?? 'Verniz Comum',
            'unitType': dataItem['unitType'] ?? 'litro',
            'subcategory': dataItem['subcategory'],
            'precoM2': dataItem['precoM2'],
            'hasPrecoM2': dataItem['hasPrecoM2'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } finally {
      _criandoVernizComum = false;
    }
  }
}

//
// FAZER VERNIZ PU APARECER QUANDO LAMINA
//
Future<void> _ensureVernizPuForLaminas(
  DocumentSnapshot movelDoc,
  List<QueryDocumentSnapshot> itensDocs,
) async {
  // 🔒 Se já tem uma criação de Verniz PU em andamento, não faz nada
  if (_criandoVernizPu) return;

  bool temLamina = false;

  // 1) Ver se existe alguma LÂMINA neste móvel (pelo snapshot atual)
  for (final d in itensDocs) {
    final data = d.data() as Map<String, dynamic>? ?? {};
    final unitType = (data['unitType'] as String?)?.toLowerCase() ?? '';
    final sub = (data['subcategory'] as String?)?.toLowerCase() ?? '';

    if (unitType == 'folha' && sub.contains('lamina')) {
      temLamina = true;
      break;
    }
  }

  // Se não tem lâmina, não faz nada
  if (!temLamina) return;

  _criandoVernizPu = true; // 🔒 liga o cadeado
  try {
    // 2) GARANTIA NO FIRESTORE: existe Verniz PU já?
    final existing = await movelDoc.reference
        .collection('itens')
        .where('unitType', isEqualTo: 'litro')
        .where('itemName', isEqualTo: 'Verniz PU')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Já existe pelo menos um Verniz PU neste móvel → não cria outro
      return;
    }

    // 3) Buscar o item global "Verniz PU" na coleção items
    final query = await FirebaseFirestore.instance
        .collection('items')
        .where('unitType', isEqualTo: 'litro')
        .where('name', isEqualTo: 'Verniz PU')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      // não existe item "Verniz PU" cadastrado em items
      return;
    }

    final itemVerniz = query.docs.first;
    final dataItem = itemVerniz.data() as Map<String, dynamic>? ?? {};

    // 4) Copiar campos importantes para dentro do móvel
    await movelDoc.reference.collection('itens').add({
      'itemId': itemVerniz.id,
      'itemName': dataItem['name'] ?? 'Verniz PU',
      'unitType': dataItem['unitType'] ?? 'litro',
      'subcategory': dataItem['subcategory'],
      'precoM2': dataItem['precoM2'],
      'hasPrecoM2': dataItem['hasPrecoM2'],
      'createdAt': FieldValue.serverTimestamp(),
    });
  } finally {
    // libera o cadeado mesmo se der erro
    _criandoVernizPu = false;
  }
}

// ======================================================
//      EDITAR METROS DE FITA (APENAS 1 VALOR EM m)
// ======================================================

Future<void> _editFitaMetrosDialog(
  DocumentSnapshot itemDoc,
  String itemName,
) async {
  final data = itemDoc.data() as Map<String, dynamic>? ?? {};
  // campo que usamos no orçamento para quantidade de fita em metros
  final double? metrosFitaAtual = _toDouble(data['metrosFita']);

  final controller = TextEditingController(
    text: metrosFitaAtual?.toString() ?? "",
  );

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(itemName),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Metros de fita usados (m)",
            hintText: "Ex: 5.5",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              double? parse(String t) =>
                  double.tryParse(t.replaceAll(',', '.'));

              final novoValor = parse(controller.text.trim());

              try {
                await itemDoc.reference.update({
                  'metrosFita': novoValor,
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Metros de fita atualizados para "$itemName".',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Erro ao salvar metros de fita: $e",
                    ),
                  ),
                );
              }

              // fecha o diálogo
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _editPinturaDialog(
  DocumentSnapshot movelDoc,
  DocumentSnapshot itemDoc,
  String itemName,
) async {
  final data = itemDoc.data() as Map<String, dynamic>? ?? {};

  // ⬇️ usamos uma lista separada só para pintura
  final linhasData = (data['linhasPintura'] as List?) ?? [];

  // ⬇️ flag para arredondar a quantidade
  bool arredondarQuantidade = data['arredondarQuantidade'] as bool? ?? false;

  final List<LinhaFolha> linhas = [];

  if (linhasData.isNotEmpty) {
    for (final l in linhasData) {
      if (l is Map<String, dynamic>) {
        linhas.add(
          LinhaFolha(
            qtd: l['quantidade']?.toString(),
            comp: l['comprimento']?.toString(),
            larg: l['largura']?.toString(),
          ),
        );
      }
    }
  }

  if (linhas.isEmpty) {
    linhas.add(LinhaFolha());
  }

  await showDialog(
    context: context,
    builder: (ctx) {
      bool initializedFocus = false;

      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          if (!initializedFocus && linhas.isNotEmpty) {
            initializedFocus = true;
            Future.microtask(() {
              linhas.first.qtdFocus.requestFocus();
            });
          }

          void addLinha() {
            setStateDialog(() {
              linhas.add(LinhaFolha());
            });
            Future.microtask(() {
              linhas.last.qtdFocus.requestFocus();
            });
          }

          Future<void> salvar() async {
            final lista = <Map<String, dynamic>>[];

            for (final l in linhas) {
              final map = l.toMap();
              final allEmpty = (map['quantidade'] as String).isEmpty &&
                  (map['comprimento'] as String).isEmpty &&
                  (map['largura'] as String).isEmpty;
              if (!allEmpty) {
                lista.add(map);
              }
            }

            try {
              await itemDoc.reference.update({
                // ⬇️ salva as linhas da PINTURA
                'linhasPintura': lista,
                // ⬇️ salva se deve arredondar ou não
                'arredondarQuantidade': arredondarQuantidade,
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Medidas de pintura salvas para "$itemName".'),
                  ),
                );
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Erro ao salvar medidas de pintura: $e"),
                  ),
                );
              }
            }
          }

          Posicao? findPosicaoAtual() {
            final current = FocusManager.instance.primaryFocus;
            if (current == null) return null;

            for (var i = 0; i < linhas.length; i++) {
              final l = linhas[i];
              if (current == l.qtdFocus) return Posicao(i, 0);
              if (current == l.compFocus) return Posicao(i, 1);
              if (current == l.largFocus) return Posicao(i, 2);
            }
            return null;
          }

          void moveFocus({
            int deltaLinha = 0,
            int deltaColuna = 0,
            bool criarSeDownNoFinal = false,
          }) {
            final pos = findPosicaoAtual();
            if (pos == null) return;

            int linha = pos.linha;
            int coluna = pos.coluna;

            // mover coluna
            if (deltaColuna != 0) {
              final newCol = coluna + deltaColuna;
              if (newCol < 0 || newCol > 2) {
                return;
              }
              coluna = newCol;
            }

            // mover linha
            if (deltaLinha != 0) {
              final newLinha = linha + deltaLinha;
              if (newLinha < 0) return;

              if (newLinha >= linhas.length) {
                // seta pra baixo na última linha -> cria nova e vai pra Qtd
                if (criarSeDownNoFinal && deltaLinha > 0) {
                  addLinha();
                  linha = linhas.length - 1;
                  coluna = 0; // sempre começa em Quantidade
                } else {
                  return;
                }
              } else {
                linha = newLinha;
              }
            }

            final l = linhas[linha];
            FocusNode node;
            if (coluna == 0) {
              node = l.qtdFocus;
            } else if (coluna == 1) {
              node = l.compFocus;
            } else {
              node = l.largFocus;
            }

            Future.microtask(() {
              node.requestFocus();
            });
          }

          return Shortcuts(
            shortcuts: <LogicalKeySet, Intent>{
              LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                  const MoveLeftIntent(),
              LogicalKeySet(LogicalKeyboardKey.arrowRight):
                  const MoveRightIntent(),
              LogicalKeySet(LogicalKeyboardKey.arrowUp):
                  const MoveUpIntent(),
              LogicalKeySet(LogicalKeyboardKey.arrowDown):
                  const MoveDownIntent(),
              LogicalKeySet(LogicalKeyboardKey.enter):
                  const SaveIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                MoveLeftIntent: CallbackAction<MoveLeftIntent>(
                  onInvoke: (intent) {
                    moveFocus(deltaColuna: -1);
                    return null;
                  },
                ),
                MoveRightIntent: CallbackAction<MoveRightIntent>(
                  onInvoke: (intent) {
                    moveFocus(deltaColuna: 1);
                    return null;
                  },
                ),
                MoveUpIntent: CallbackAction<MoveUpIntent>(
                  onInvoke: (intent) {
                    moveFocus(deltaLinha: -1);
                    return null;
                  },
                ),
                MoveDownIntent: CallbackAction<MoveDownIntent>(
                  onInvoke: (intent) {
                    moveFocus(
                      deltaLinha: 1,
                      criarSeDownNoFinal: true,
                    );
                    return null;
                  },
                ),
                SaveIntent: CallbackAction<SaveIntent>(
                  onInvoke: (intent) {
                    salvar();
                    return null;
                  },
                ),
              },
              child: FocusScope(
                autofocus: true,
                child: AlertDialog(
                  title: Text('Medidas Pintura - $itemName'),
                  content: SizedBox(
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Use as setas para navegar. ↓ na última linha adiciona nova linha. ENTER salva.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 260,
                          child: ListView.builder(
                            itemCount: linhas.length,
                            itemBuilder: (context, index) {
                              final linha = linhas[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      height: 34,
                                      child: TextField(
                                        controller:
                                            linha.qtdController,
                                        focusNode: linha.qtdFocus,
                                        keyboardType:
                                            TextInputType.number,
                                        decoration:
                                            const InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 8,
                                          ),
                                          border:
                                              OutlineInputBorder(),
                                          labelText: "Qtd",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 120,
                                      height: 34,
                                      child: TextField(
                                        controller:
                                            linha.compController,
                                        focusNode: linha.compFocus,
                                        keyboardType:
                                            const TextInputType
                                                    .numberWithOptions(
                                                decimal: true),
                                        decoration:
                                            const InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 8,
                                          ),
                                          border:
                                              OutlineInputBorder(),
                                          labelText: "Comp",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 120,
                                      height: 34,
                                      child: TextField(
                                        controller:
                                            linha.largController,
                                        focusNode: linha.largFocus,
                                        keyboardType:
                                            const TextInputType
                                                    .numberWithOptions(
                                                decimal: true),
                                        decoration:
                                            const InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 8),
                                          border:
                                              OutlineInputBorder(),
                                          labelText: "Larg",
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (linhas.length > 1)
                                      IconButton(
                                        onPressed: () {
                                          setStateDialog(() {
                                            linhas.removeAt(index);
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.close,
                                          size: 18,
                                        ),
                                        tooltip: "Remover linha",
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: addLinha,
                            icon: const Icon(Icons.add),
                            label: const Text("Adicionar linha"),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // ⬇️ Checkbox "Arredondar quantidade"
                        CheckboxListTile(
                          value: arredondarQuantidade,
                          onChanged: (v) {
                            setStateDialog(() {
                              arredondarQuantidade = v ?? false;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title:
                              const Text("Arredondar quantidade"),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancelar"),
                    ),
                    TextButton(
                      onPressed: salvar,
                      child: const Text(
                        "Salvar",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  // ======================================================
  //      EDITAR CONFIGURAÇÃO DE COLA FORMICA POR MÓVEL
  // ======================================================

Future<void> _editColaFormicaDialog(
  DocumentSnapshot movelDoc,
  DocumentSnapshot itemDoc,
  String itemName,
) async {
  // 1) Buscar todos os itens desse móvel
  final itensSnapshot =
      await movelDoc.reference.collection('itens').get();

  final todosItensMovel = itensSnapshot.docs;

  // Itens elegíveis: MDF, Fitas, Formica, Lâmina, Manta
  const allowedSubcats = [
    'mdf',
    'fita',
    'formica',
    'lamina',
    'manta',
  ];

  final elegiveis = todosItensMovel.where((d) {
    final data = d.data() as Map<String, dynamic>? ?? {};
    final unitType = data['unitType'];
    final subcat = (data['subcategory'] as String?)?.toLowerCase();

    if (unitType == 'litro') return false; // ignora tintas/colas etc.

    if (subcat != null && allowedSubcats.contains(subcat)) {
      return true;
    }
    return false;
  }).toList();

  // 2) Carregar dados já salvos nesse item (cola formica)
  final data = itemDoc.data() as Map<String, dynamic>? ?? {};
  final linhasData = (data['colaFormicaItens'] as List?) ?? [];
  final extraLitrosExistente = (data['extraLitros'] as num?)?.toDouble();
  final double lm2Mdf = _toDouble(data['lm2Mdf']) ?? 0;
  final double lm2Formica = _toDouble(data['lm2Formica']) ?? 0;

  // Lista de IDs de itens do móvel selecionados em cada linha
  final List<String?> selectedIds = [];

  if (elegiveis.isNotEmpty) {
    // Só tenta reconstruir linhas se existirem itens elegíveis
    for (final l in linhasData) {
      if (l is Map<String, dynamic>) {
        final id = l['itemMovelId'] as String?;
        selectedIds.add(id);
      }
    }

    if (selectedIds.isEmpty) {
      selectedIds.add(null); // pelo menos 1 linha vazia
    }
  }

  final extraLitrosController = TextEditingController(
    text: extraLitrosExistente != null ? extraLitrosExistente.toString() : "",
  );

  DocumentSnapshot? findById(
      List<QueryDocumentSnapshot> list, String id) {
    for (final d in list) {
      if (d.id == id) return d;
    }
    return null;
  }

  if (!mounted) return;

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text('Cola Formica - $itemName'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (elegiveis.isEmpty) ...[
                    const Text(
                      "Não há itens elegíveis (MDF, Fitas, Formica, Lâminas ou Mantas) "
                      "cadastrados neste móvel.\n\n"
                      "Você ainda pode informar apenas os litros extras de Cola Formica.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Text(
                      "Selecione os itens deste móvel que utilizam Cola Formica.\n"
                      "Cada linha representa um item que usa a cola. À direita aparece os L calculados.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // Lista de linhas (dropdowns + L calculado)
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        itemCount: selectedIds.length,
                        itemBuilder: (context, index) {
                          final currentId = selectedIds[index];

                          // cálculo dos litros desse item específico
                          double? litrosCalculado;
                          if (currentId != null) {
                            final docSel = findById(elegiveis, currentId);
                            if (docSel != null) {
                              litrosCalculado =
                                  _calcularLitrosColaFormicaParaItem(
                                docSel,
                                lm2Mdf,
                                lm2Formica,
                              );
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    isExpanded: true,
                                    initialValue: currentId,
                                    decoration: const InputDecoration(
                                      labelText: "Item do móvel",
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    // 🔥 Itens filtrados para NÃO repetir seleções
                                    items: () {
                                      // IDs já usados em outras linhas (diferentes da atual)
                                      final usedIds = selectedIds
                                          .where((id) =>
                                              id != null && id != currentId)
                                          .toSet();

                                      return <DropdownMenuItem<String?>>[
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text("- selecione -"),
                                        ),
                                        ...elegiveis
                                            .where((d) => !usedIds.contains(d.id))
                                            .map((d) {
                                          final dd = d.data()
                                                  as Map<String, dynamic>? ??
                                              {};
                                          final nomeItem =
                                              dd['itemName'] as String? ??
                                                  "(sem nome)";
                                          return DropdownMenuItem<String?>(
                                            value: d.id,
                                            child: Text(
                                              nomeItem,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }),
                                      ];
                                    }(),
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        selectedIds[index] = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    (litrosCalculado == null ||
                                            litrosCalculado == 0)
                                        ? "-"
                                        : "${_formatDecimal(litrosCalculado, dec: 2)} L",
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (selectedIds.length > 1)
                                  IconButton(
                                    onPressed: () {
                                      setStateDialog(() {
                                        selectedIds.removeAt(index);
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                    tooltip: "Remover linha",
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setStateDialog(() {
                            selectedIds.add(null);
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("Adicionar linha"),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Litros extras de Cola Formica (opcional)",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: extraLitrosController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: "Ex: 0.5",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () async {
                  // Montar lista final de itens selecionados
                  final List<Map<String, dynamic>> itensSelecionados = [];

                  if (elegiveis.isNotEmpty) {
                    for (final id in selectedIds) {
                      if (id == null) continue;
                      final docSel = findById(elegiveis, id);
                      if (docSel == null) continue;

                      final dData =
                          docSel.data() as Map<String, dynamic>? ?? {};
                      final nomeItem =
                          dData['itemName'] as String? ?? "(sem nome)";

                      itensSelecionados.add({
                        'itemMovelId': docSel.id,
                        'itemName': nomeItem,
                      });
                    }
                  }

                  double? extra;
                  final txt = extraLitrosController.text.trim();
                  if (txt.isNotEmpty) {
                    extra = double.tryParse(
                        txt.replaceAll(',', '.'));
                  }

                  try {
                    await itemDoc.reference.update({
                      'colaFormicaItens': itensSelecionados,
                      'extraLitros': extra,
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text("Configuração de Cola Formica salva."),
                        ),
                      );
                    }
                    // ignore: use_build_context_synchronously
                    Navigator.pop(ctx);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text("Erro ao salvar Cola Formica: $e"),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  "Salvar",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

  // ======================================================
  // BUILD
  // ======================================================

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
    title: const Text("Orçamento"),
    actions: [
      IconButton(
        onPressed: _salvarResumoTodosMoveis, // ✅ NEW
        icon: const Icon(Icons.save),
        tooltip: "Salvar resumo",
      ),
      IconButton(
        onPressed: _gerarPdfOrcamento,
        icon: const Icon(Icons.picture_as_pdf),
        tooltip: "Gerar PDF",
      ),
    ],
  ),
    body: ListView(
      controller: _scrollCtrl,
      key: _orcamentoScrollKey,
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildMoveisSection(context),
        const SizedBox(height: 24),
      ],
    ),
      floatingActionButton: MouseRegion(
  onEnter: (_) => setState(() => _isFabHovered = true),
  onExit: (_) => setState(() => _isFabHovered = false),
  child: GestureDetector(
    onTap: () => _showAddMovelDialog(context), // ✅ ADD MÓVEL
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _isFabHovered ? 64 : 56,
      height: _isFabHovered ? 64 : 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black87,
          width: 1.5,
        ),
        boxShadow: _isFabHovered
            ? [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ]
            : [],
      ),
      child: const Center(
        child: Icon(
          Icons.add,
          color: Colors.black87,
        ),
      ),
    ),
  ),
),

// ✅ BOTTOM LEFT
floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
  // ======================================================
  //                EDITAR UNIDADE
  // ======================================================

  Future<void> _editUnidadeQuantidadeDialog(
    DocumentSnapshot itemDoc,
    String itemName,
  ) async {
    final data = itemDoc.data() as Map<String, dynamic>? ?? {};
    final quantidadeExistente = data['quantidadeUnd'] as num?;

    final controller = TextEditingController(
      text: quantidadeExistente != null ? quantidadeExistente.toString() : "",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade - $itemName'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Quantidade de itens",
              hintText: "Ex: 4",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              final txt = controller.text.trim();
              final valor = double.tryParse(txt.replaceAll(',', '.'));

              try {
                await itemDoc.reference.update({
                  'quantidadeUnd': valor,
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Quantidade de "$itemName" atualizada para ${valor ?? "-"} Und',
                      ),
                    ),
                  );
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erro ao salvar quantidade: $e"),
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AcaoMovel {
  duplicar,
  guardar,
  excluir,
}

// ======================================================
//                  SEÇÃO DE MÓVEIS
// ======================================================

extension _MoveisExtension on _OrcamentoPageState {
  Widget _buildMoveisSection(BuildContext context) {

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot>(
        stream: _moveisStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              "Erro ao carregar móveis: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text(
              "Carregando móveis...",
              style: TextStyle(color: Colors.grey),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text(
              "Nenhum móvel adicionado ainda.",
              style: TextStyle(color: Colors.grey),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildMovelCard(context, doc),
              );
            },
          );
        },
      ),
    ],
  );
}

  Widget _buildMovelCard(
  BuildContext context,
  DocumentSnapshot doc,
) {
  
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final nomeMovel = data['nome'] as String? ?? "(sem nome)";

    final itensQuery = doc.reference
        .collection('itens')
        .orderBy('createdAt', descending: false);

    return Container(
      key: ValueKey(doc.id),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho do móvel
          Row(
            children: [
              Expanded(
                child: Text(
                  "(${data['numeroMovel']}) $nomeMovel",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showAddItemMovelDialog(context, doc),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: "Adicionar item",
              ),
              IconButton(
                onPressed: () => _mostrarOpcoesMovel(context, doc, nomeMovel),
                icon: const Icon(Icons.more_vert),
                tooltip: "Opções do móvel",
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Cabeçalho da "tabela"
          Container(
            key: ValueKey(doc.id),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.06),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    "Item",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Medida",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Tamanho",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Quantidade",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Preço",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Total",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ITENS + RESUMO
StreamBuilder<QuerySnapshot>(
  stream: itensQuery.snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Text(
        "Erro ao carregar itens: ${snapshot.error}",
        style: const TextStyle(color: Colors.red),
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Text(
        "Carregando itens...",
        style: TextStyle(color: Colors.grey),
      );
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return const Text(
        "Nenhum item adicionado ainda.",
        style: TextStyle(color: Colors.grey),
      );
    }

    final itensDocs = snapshot.data!.docs.toList();
    // tentar garantir que Verniz PU exista se tiver lâmina
    _ensureVernizPuForLaminas(doc, itensDocs);
    _ensureVernizesParaMadeiraMacica(doc, itensDocs);

    // ========= 1ª PASSAGEM: calcular TOTAL BRUTO =========
    double totalBruto = 0;

    for (final itemDoc in itensDocs) {
      final itemData =
          itemDoc.data() as Map<String, dynamic>? ?? {};
      final itemName =
          itemData['itemName'] as String? ?? "(sem nome)";
      final unitType = itemData['unitType'];
      final subcategoryItem = itemData['subcategory'];
      final subLower =
          (subcategoryItem as String?)?.toLowerCase() ?? '';

      final bool isFolha = unitType == 'folha';
      final bool isColaBranca =
          unitType == 'litro' &&
          itemName.toLowerCase() == 'cola branca';
      final bool isColaFormica =
          unitType == 'litro' &&
          itemName.toLowerCase() == 'cola formica';
      final bool isUnidade = unitType == 'unidade';
      final bool isFita = subLower == 'fita' || subLower == 'fitas';
      final bool isOutros = subLower == 'outros' || subLower == 'outro';
      final bool isPintura =
          unitType == 'litro' && subLower == 'tintas';
      final bool isMadeiraMacica = unitType == 'madeiraMacica';
      // genérico
      final quantidadeUsada =
          _toDouble(itemData['quantidadeUsada']);
      final precoPorQuantidade =
          _toDouble(itemData['precoPorQuantidade']);
      final bool isVernizPu = unitType == 'litro' &&
          itemName.toLowerCase() == 'verniz pu';
      final bool isVernizComum = unitType == 'litro' &&
          itemName.toLowerCase() == 'verniz comum';
      final bool isValorTotal = isUnidade && (itemData['isValorTotal'] == true);
          

// --- FOLHA ---
final linhasFolha = (itemData['linhas'] as List?) ?? [];
final double? areaFolha = _toDouble(itemData['areaFolha']); // m² por folha
final double? precoFolha = _toDouble(itemData['precoFolha']);
final double taxaPerca = _toDouble(itemData['taxaPerca']) ?? 0;

double? tamanhoFolha;     // m² total
double? quantidadeFolha;  // nº de folhas (quando digitado)
double? totalFolha;

if (isFolha) {
  double somaM2 = 0;
  double somaFolhas = 0;
  bool usouQtdFolhas = false;

  for (final raw in linhasFolha) {
    if (raw is! Map<String, dynamic>) continue;

    final qFolhas = _toDouble(raw['qtdFolhas']); // <-- ajuste a key se necessário

    if (qFolhas != null && qFolhas > 0 && areaFolha != null && areaFolha > 0) {
      usouQtdFolhas = true;
      somaFolhas += qFolhas;
      somaM2 += qFolhas * areaFolha;
      continue;
    }

    final q = _toDouble(raw['quantidade']);
    final c = _toDouble(raw['comprimento']);
    final g = _toDouble(raw['largura']);
    if (q != null && c != null && g != null) {
      somaM2 += q * (c * g / 10000.0);
    }
  }

  if (somaM2 > 0) tamanhoFolha = somaM2;

  if (somaFolhas > 0) {
    quantidadeFolha = somaFolhas; // digitado
  } else if (tamanhoFolha != null && areaFolha != null && areaFolha > 0) {
    quantidadeFolha = tamanhoFolha / areaFolha; // calculado
  }

  if (quantidadeFolha != null && precoFolha != null) {
    // ✅ taxaPerca SÓ quando NÃO usou qtdFolhas
    final fatorPerca = usouQtdFolhas ? 1.0 : (1 + (taxaPerca / 100.0));
    totalFolha = precoFolha * quantidadeFolha * fatorPerca;
  }
}

      // ====== UNIDADE ======
final double? quantidadeUnd = _toDouble(itemData['quantidadeUnd']);
final double? precoUnidadeItem = _toDouble(itemData['precoUnidade']); // preço da tabela
final double? precoUndMovel    = _toDouble(itemData['precoUnd']);     // preço customizado do "Valor Total"

// usa o mesmo itemName que você já tem lá em cima

double? totalUnidade;

if (isUnidade && quantidadeUnd != null) {
  if (isValorTotal) {
    // ⭐ Valor Total: usa o precoUnd (se existir) senão cai pro precoUnidade da tabela
    final double? precoBase = precoUndMovel ?? precoUnidadeItem;
    if (precoBase != null) {
      totalUnidade = quantidadeUnd * precoBase;
    }
  } else {
    // Unidade normal
    if (precoUnidadeItem != null) {
      totalUnidade = quantidadeUnd * precoUnidadeItem;
    }
  }
}
// ====== VERNIZ PU / VERNIZ COMUM (1ª PASSAGEM) ======
double? totalVernizPu;

double? totalVernizComum;

// Área total da madeira que usa Verniz PU
final double areaMadeiraPu =
    _calcularAreaM2VernizParaMovel(itensDocs, paraVernizPu: true);

// Área total da madeira que usa Verniz Comum
final double areaMadeiraComum =
    _calcularAreaM2VernizParaMovel(itensDocs, paraVernizPu: false);

// Área das LÂMINAS (entra só na conta do Verniz PU)
final double areaLaminas =
    _calcularAreaM2TotalLaminas(itensDocs);

// ------- VERNIZ PU -------
if (isVernizPu) {
  final double areaTotal = areaMadeiraPu + areaLaminas;

  if (areaTotal > 0) {

    final precoM2 = _toDouble(itemData['precoM2']);
    if (precoM2 != null && precoM2 > 0) {
      totalVernizPu = precoM2 * areaTotal;
    }
  } else {
    // 🔥 força sumir da tabela
    totalVernizPu = null;
  }
}

// ------- VERNIZ COMUM -------
if (isVernizComum) {
  final double areaTotal = areaMadeiraComum;

  if (areaTotal > 0) {

    final precoM2 = _toDouble(itemData['precoM2']);
    if (precoM2 != null && precoM2 > 0) {
      totalVernizComum = precoM2 * areaTotal;
    }
  } else {
    // 🔥 força sumir da tabela
    totalVernizComum = null;
  }
}

// ====== COLA FORMICA ======
double? colaLitrosTotal;
double? colaPrecoL;

if (isColaFormica) {
  final double lm2Mdf = _toDouble(itemData['lm2Mdf']) ?? 0;
  final double lm2Formica = _toDouble(itemData['lm2Formica']) ?? 0;
  colaPrecoL = _toDouble(itemData['precoL']);

  double somaLitros = 0;

  final listaItens =
      (itemData['colaFormicaItens'] as List?) ?? [];
  for (final cfg in listaItens) {
    if (cfg is Map<String, dynamic>) {
      final id = cfg['itemMovelId'] as String?;
      if (id == null) continue;

      DocumentSnapshot? alvo;
      for (final d in itensDocs) {
        if (d.id == id) {
          alvo = d;
          break;
        }
      }
      if (alvo == null) continue;

      // LITROS (quantidade em L)
      somaLitros += _calcularLitrosColaFormicaParaItem(
        alvo,
        lm2Mdf,
        lm2Formica,
      );

    }
  }

  final extraLitros = _toDouble(itemData['extraLitros']) ?? 0;
  somaLitros += extraLitros;

  if (somaLitros > 0) colaLitrosTotal = somaLitros;
}

      // ====== COLA BRANCA (L) ======
      final litrosColaBranca = _toDouble(itemData['litros']);
      final precoLColaBranca = _toDouble(itemData['precoL']);
      double? totalColaBranca;
      if (isColaBranca &&
          litrosColaBranca != null &&
          precoLColaBranca != null) {
        totalColaBranca = litrosColaBranca * precoLColaBranca;
      }

      // ====== FITA (m) ======
      final metrosFita =
          _toDouble(itemData['metrosFita']); // digitado na página do orçamento
      final precoTotalFita =
          _toDouble(itemData['precoMetro']); // preço TOTAL do item
      final metragemItem =
          _toDouble(itemData['metragem']); // metragem cadastrada no item

      double? precoPorMetroFita;
      double? totalFita;

      if ((isFita || isOutros)&&
          metrosFita != null &&
          precoTotalFita != null &&
          metragemItem != null &&
          metragemItem > 0) {
        precoPorMetroFita = precoTotalFita / metragemItem; // R$/m
        totalFita = metrosFita * precoPorMetroFita;
      }

// --- PINTURA ---
final precoM2Pintura = _toDouble(itemData['precoM2']);
double? pinturaM2;
double? quantidadePintura;
double? totalPintura;

if (isPintura) {
  final linhasPintura = (itemData['linhasPintura'] as List?) ?? [];
  final bool arredondarQtde = itemData['arredondarQuantidade'] == true;

  double somaM2 = 0;

  for (final l in linhasPintura) {
    if (l is Map<String, dynamic>) {
      final q = _toDouble(l['quantidade']);
      final c = _toDouble(l['comprimento']);
      final g = _toDouble(l['largura']);

      if (q != null && c != null && g != null) {
        somaM2 += q * (c * g / 10000.0); // cm² → m²
      }
    }
  }

  if (somaM2 > 0) {
    pinturaM2 = somaM2;

    // QUANTIDADE usada na tabela
    quantidadePintura =
        arredondarQtde ? somaM2.ceilToDouble() : somaM2;

    // TOTAL deve usar QUANTIDADE se arredondado
    if (precoM2Pintura != null) {
      totalPintura = arredondarQtde
          ? quantidadePintura! * precoM2Pintura
          : pinturaM2 * precoM2Pintura;
    }
  }
}

      // MADEIRA MACIÇA
      final volume = _calcularVolumeM3Madeira(itemDoc);
      final precoM3 = _toDouble(itemData['precoM3']) ?? 0;
      final totalMadeiraMacica = (volume/1000000) * precoM3;

      // ====== SOMA NO TOTAL BRUTO ======
      double totalItem = 0;

      if (isFolha && totalFolha != null) {
        totalItem = totalFolha;
      } else if (isUnidade && totalUnidade != null) {
        totalItem = totalUnidade;
      } else if (isColaFormica &&
          colaLitrosTotal != null &&
          colaPrecoL != null) {
        totalItem = colaLitrosTotal * colaPrecoL;
      } else if (isColaBranca && totalColaBranca != null) {
        totalItem = totalColaBranca;
      } else if ((isFita || isOutros) && totalFita != null) {
        totalItem = totalFita;
      } else if (isPintura && totalPintura != null) {
        totalItem = totalPintura * 1.20;
      } else if (isVernizPu && totalVernizPu != null) {
        totalItem = totalVernizPu;
      } else if (isVernizComum && totalVernizComum != null) {
        totalItem = totalVernizComum;
      } else if (isMadeiraMacica) {
        totalItem = totalMadeiraMacica;
      } else if (!isFolha &&
          !isUnidade &&
          !isColaFormica &&
          !isColaBranca &&
          !isFita &&
          !isOutros &&
          !isPintura) {
        final q = quantidadeUsada;
        final p = precoPorQuantidade;
        if (q != null && p != null) {
          totalItem = q * p;
        }
      }

      totalBruto += totalItem;
    }

    // ========= 2ª PASSAGEM: desenhar linhas dos itens + Total Bruto =========
    return Column(
      children: [
        // Tabela de itens
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itensDocs.length,
          itemBuilder: (context, index) {
            final itemDoc = itensDocs[index];
            final itemData =
                itemDoc.data() as Map<String, dynamic>? ?? {};
            final itemName =
                itemData['itemName'] as String? ?? "(sem nome)";
            final unitType = itemData['unitType'];
            final subcategoryItem = itemData['subcategory'];
            final subLower =
                (subcategoryItem as String?)?.toLowerCase() ?? '';
            

            final bool isFolha = unitType == 'folha';
            final bool isColaBranca =
                unitType == 'litro' &&
                itemName.toLowerCase() == 'cola branca';
            final bool isColaFormica =
                unitType == 'litro' &&
                itemName.toLowerCase() == 'cola formica';
            final bool isUnidade = unitType == 'unidade';
            final bool isFita =
                subLower == 'fita' || subLower == 'fitas';
            final bool isOutros =
                subLower == 'outros' || subLower == 'outro';
            final bool isPintura =
                unitType == 'litro' && subLower == 'tintas';
            final bool isMadeiraMacica = unitType == 'madeiraMacica';
            final bool isVernizPu = unitType == 'litro' &&
                itemName.toLowerCase() == 'verniz pu';
            final bool isVernizComum = unitType == 'litro' &&
                itemName.toLowerCase() == 'verniz comum';
            final bool isValorTotal = isUnidade && (itemData['isValorTotal'] == true);
          

            // valores genéricos (para outros tipos)
            final medidaUsada = _toDouble(itemData['medidaUsada']);
            final quantidadeUsada =
                _toDouble(itemData['quantidadeUsada']);
            final precoPorQuantidade =
                _toDouble(itemData['precoPorQuantidade']);

            final unidadeMedida =
                _unitSuffix(unitType as String?);

// --- FOLHA ---
final linhasFolha = (itemData['linhas'] as List?) ?? [];
final double? areaFolha = _toDouble(itemData['areaFolha']); // m² por folha
final double? precoFolha = _toDouble(itemData['precoFolha']);
final double taxaPerca = _toDouble(itemData['taxaPerca']) ?? 0;

double? tamanhoFolha;     // m² total
double? quantidadeFolha;  // nº de folhas (quando digitado)
double? totalFolha;

if (isFolha) {
  double somaM2 = 0;
  double somaFolhas = 0;

  for (final raw in linhasFolha) {
    if (raw is! Map<String, dynamic>) continue;

    final qFolhas = _toDouble(raw['qtdFolhas']); // <-- ajuste a key se necessário

    if (qFolhas != null && qFolhas > 0 && areaFolha != null && areaFolha > 0) {
      somaFolhas += qFolhas;
      somaM2 += qFolhas * areaFolha;
      continue;
    }

    final q = _toDouble(raw['quantidade']);
    final c = _toDouble(raw['comprimento']);
    final g = _toDouble(raw['largura']);
    if (q != null && c != null && g != null) {
      somaM2 += q * (c * g / 10000.0);
    }
  }

  if (somaM2 > 0) tamanhoFolha = somaM2;

  final quantidadeperca = 1 + (taxaPerca/100);

  if (somaFolhas > 0) {
    quantidadeFolha = somaFolhas; // digitado
  } else if (tamanhoFolha != null && areaFolha != null && areaFolha > 0) {
    quantidadeFolha = (tamanhoFolha / areaFolha) * quantidadeperca; // calculado
  }

  if (quantidadeFolha != null && precoFolha != null) {
    // ✅ taxaPerca SÓ quando NÃO usou qtdFolhas
    totalFolha = precoFolha * quantidadeFolha;
  }
}



// --- PINTURA ---
final precoM2Pintura = _toDouble(itemData['precoM2']);
double? pinturaM2;
double? quantidadePintura;
double? totalPintura;

if (isPintura) {
  final linhasPintura = (itemData['linhasPintura'] as List?) ?? [];
  final bool arredondarQtde = itemData['arredondarQuantidade'] == true;

  double somaM2 = 0;

  for (final l in linhasPintura) {
    if (l is Map<String, dynamic>) {
      final q = _toDouble(l['quantidade']);
      final c = _toDouble(l['comprimento']);
      final g = _toDouble(l['largura']);

      if (q != null && c != null && g != null) {
        somaM2 += q * (c * g / 10000.0); // cm² → m²
      }
    }
  }

  if (somaM2 > 0) {
    pinturaM2 = somaM2;

    // QUANTIDADE usada na tabela
    quantidadePintura =
        arredondarQtde ? somaM2.ceilToDouble() : somaM2;

    // TOTAL deve usar QUANTIDADE se arredondado
    if (precoM2Pintura != null) {
      totalPintura = arredondarQtde
          ? quantidadePintura! * precoM2Pintura
          : pinturaM2 * precoM2Pintura;
    }
  }
}

            // ====== UNIDADE ======
final double? quantidadeUnd = _toDouble(itemData['quantidadeUnd']);

// usa o mesmo itemName que você já tem lá em cima


// ====== VERNIZ PU / VERNIZ COMUM (1ª PASSAGEM) ======
double? vernizPuM2;
double? vernizPuLitros;
double? totalVernizPu;

double? vernizComumM2;
double? vernizComumLitros;
double? totalVernizComum;

// Área total da madeira que usa Verniz PU
final double areaMadeiraPu =
    _calcularAreaM2VernizParaMovel(itensDocs, paraVernizPu: true);

// Área total da madeira que usa Verniz Comum
final double areaMadeiraComum =
    _calcularAreaM2VernizParaMovel(itensDocs, paraVernizPu: false);

// Área das LÂMINAS (entra só na conta do Verniz PU)
final double areaLaminas = _calcularAreaM2TotalLaminas(itensDocs);

// ------- VERNIZ PU -------
if (isVernizPu) {
  final double areaTotal = areaMadeiraPu + areaLaminas;

  if (areaTotal > 0) {
    vernizPuM2 = areaTotal;
    vernizPuLitros = areaTotal; // 1 L para 1 m²
    final precoM2 = _toDouble(itemData['precoM2']);
    if (precoM2 != null) {
      totalVernizPu = precoM2 * areaTotal;
    }
  }
}

// ------- VERNIZ COMUM -------
if (isVernizComum) { // se seu bool chama isVernizNormal, troque aqui
  final double areaTotal = areaMadeiraComum;

  if (areaTotal > 0) {
    vernizComumM2 = areaTotal;
    vernizComumLitros = areaTotal;
    final precoM2 = _toDouble(itemData['precoM2']);
    if (precoM2 != null) {
      totalVernizComum = precoM2 * areaTotal;
    }
  }
}

// ====== COLA FORMICA ======
double? colaLitrosTotal;
double? colaPrecoL;
double? colaMetrosTotal;
double? colaM2Total;

if (isColaFormica) {
  final double lm2Mdf = _toDouble(itemData['lm2Mdf']) ?? 0;
  final double lm2Formica = _toDouble(itemData['lm2Formica']) ?? 0;
  colaPrecoL = _toDouble(itemData['precoL']);

  double somaLitros = 0;
  double somaMetros = 0;
  double somaM2 = 0;

  final listaItens =
      (itemData['colaFormicaItens'] as List?) ?? [];
  for (final cfg in listaItens) {
    if (cfg is Map<String, dynamic>) {
      final id = cfg['itemMovelId'] as String?;
      if (id == null) continue;

      DocumentSnapshot? alvo;
      for (final d in itensDocs) {
        if (d.id == id) {
          alvo = d;
          break;
        }
      }
      if (alvo == null) continue;

      // LITROS (quantidade em L)
      somaLitros += _calcularLitrosColaFormicaParaItem(
        alvo,
        lm2Mdf,
        lm2Formica,
      );

      // TAMANHO (m / m²) só pra exibir
      final dataAlvo =
          alvo.data() as Map<String, dynamic>? ?? {};
      final unitTypeAlvo =
          (dataAlvo['unitType'] as String?)?.toLowerCase() ?? '';
      final subAlvo =
          (dataAlvo['subcategory'] as String?)?.toLowerCase() ?? '';

      if (unitTypeAlvo != 'litro') {
        if (subAlvo.contains('fita')) {
          final metrosFita = _toDouble(dataAlvo['metrosFita']);
          final quantidadeUsadaSel =
              _toDouble(dataAlvo['quantidadeUsada']);
          final metragemItemSel =
              _toDouble(dataAlvo['metragem']);
          final metros =
              metrosFita ?? quantidadeUsadaSel ?? metragemItemSel ?? 0;
          if (metros > 0) somaMetros += metros;
        } else {
          final area = _calcularAreaM2DeFolha(alvo);
          if (area > 0) somaM2 += area;
        }
      }
    }
  }

  final extraLitros = _toDouble(itemData['extraLitros']) ?? 0;
  somaLitros += extraLitros;

  if (somaLitros > 0) colaLitrosTotal = somaLitros;
  if (somaMetros > 0) colaMetrosTotal = somaMetros;
  if (somaM2 > 0) colaM2Total = somaM2;
}

            // ====== COLA BRANCA ======
            final litrosColaBranca =
                _toDouble(itemData['litros']);
            final precoLColaBranca = _toDouble(itemData['precoL']);
            double? totalColaBranca;
            if (isColaBranca &&
                litrosColaBranca != null &&
                precoLColaBranca != null) {
              totalColaBranca =
                  litrosColaBranca * precoLColaBranca;
            }

            // ====== FITA ======
            final metrosFitaItem =
                _toDouble(itemData['metrosFita']);
            final precoTotalFitaItem =
                _toDouble(itemData['precoMetro']);
            final metragemItem =
                _toDouble(itemData['metragem']);

            double? totalFita;
            double? precoPorMetroFitaLinha;
            double? quantidadefitaitem;
            if ((isFita || isOutros) &&
                metrosFitaItem != null &&
                precoTotalFitaItem != null &&
                metragemItem != null &&
                metragemItem > 0) {
              precoPorMetroFitaLinha =
                  precoTotalFitaItem / metragemItem;
              totalFita = metrosFitaItem * precoPorMetroFitaLinha;
              quantidadefitaitem = metrosFitaItem / metragemItem;
            }

            // ✅ AQUI ENTRA ESSE IF DE ESCONDER:
            if (isVernizPu && (vernizPuM2 == null || vernizPuM2 == 0)) {
              return const SizedBox.shrink();
            }

            if (isVernizComum && (vernizComumM2 == null || vernizComumM2 == 0)) {
              return const SizedBox.shrink();
            }

            return Dismissible(
              key: ValueKey(itemDoc.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.red.withValues(alpha: 0.8),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Remover item"),
                        content: Text(
                            'Deseja remover o item "$itemName" deste móvel?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, false),
                            child: const Text("Cancelar"),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, true),
                            child: const Text(
                              "Remover",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (direction) async {
                try {
                  await itemDoc.reference.delete();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Item "$itemName" removido de "$nomeMovel".'),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text("Erro ao remover item: $e"),
                    ),
                  );
                }
              },
              child: InkWell(
                key: ValueKey(doc.id),
                onTap: () {
                  if (isFolha) {
                    _editFolhaMedidasDialog(
                        doc, itemDoc, itemName);
                  } else if (isColaBranca) {
                    _editColaBrancaDialog(
                        itemDoc, itemName);
                  } else if (isColaFormica) {
                    _editColaFormicaDialog(
                        doc, itemDoc, itemName);
                  } else if (isPintura) {
                    _editPinturaDialog(
                        doc, itemDoc, itemName);
                  } else if (isUnidade) {
                      if (isValorTotal) {
                        // 👉 comportamento especial pro item "Valor Total"
                        _editValorTotalDialog(itemDoc, itemName);
                      } else {
                        // 👉 todos os outros unidade continuam iguais
                        _editUnidadeQuantidadeDialog(itemDoc, itemName);
                      }
                  } else if (isFita || isOutros){
                    _editFitaMetrosDialog(
                        itemDoc,  itemName);
                  } else if (isMadeiraMacica){
                    _editMadeiraMacicaDialog(
                      doc, itemDoc, itemName);
                  }else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Edição detalhada ainda não configurada para esse tipo de item."),
                      ),
                    );
                  }
                },
                child: Container(
                  key: ValueKey(doc.id),
                  margin:
                      const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      vertical: 4, horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(4),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.03),
                  ),
                  child: Row(
                    children: [
                      // ITEM
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 6,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                itemName,
                                style: const TextStyle(
                                    fontSize: 13),
                                overflow:
                                    TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // MEDIDA
                      Expanded(
                        flex: 2,
                        child: Builder(
                          builder: (context) {
                            if (isColaFormica ||
                                isColaBranca) {
                              return const Text(
                                "L",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }

                            if (isPintura || isVernizPu || isVernizComum) {
                              return const Text(
                                "L",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }
                            if (isMadeiraMacica){
                              return const Text(
                                "m³",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }
                            if (isFita || isOutros) {
                              return const Text(
                                "m",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }

                            if (isFolha) {
                              return const Text(
                                "m²",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }
                            if (isUnidade) {
                              if (isValorTotal) {
                                final medidaVT =
                                    (itemData['medidaValorTotal'] as String?) ?? "Und";

                                return Text(
                                  medidaVT,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                );
                              }

                              // unidade normal
                              return const Text(
                                "Und",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13),
                              );
                            }

                            final medida = medidaUsada;
                            if (medida == null) {
                              return const Text(
                                "-",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }
                            return Text(
                              "${_formatDecimal(medida)} $unidadeMedida",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13),
                            );
                          },
                        ),
                      ),

                      // TAMANHO
                      Expanded(
                        flex: 2,
                        child: Builder(
                          builder: (context) {
                            if (isColaBranca) {
                              return const Text(
                                "-",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }

                            if (isColaFormica) {
                              final hasMetros = (colaMetrosTotal ?? 0) > 0;
                              final hasM2 = (colaM2Total ?? 0) > 0;

                              if (!hasMetros && !hasM2) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13),
                                );
                              }

                              String texto;
                              if (hasMetros && hasM2) {
                                texto =
                                    "${_formatDecimal(colaMetrosTotal!)} m / ${_formatDecimal(colaM2Total!)} m²";
                              } else if (hasMetros) {
                                texto =
                                    "${_formatDecimal(colaMetrosTotal!)} m";
                              } else {
                                texto =
                                    "${_formatDecimal(colaM2Total!)} m²";
                              }

                              return Text(
                                texto,
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13),
                              );
                            }

                            if (isFita || isOutros) {
                              if (metrosFitaItem ==
                                  null) {
                                return const Text(
                                  "-",
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13),
                                );
                              }
                              return Text(
                                "${_formatDecimal(metrosFitaItem)} m",
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13),
                              );
                            }

                              // dentro do Builder da coluna TAMANHO
                              if (isVernizPu) {
                                if (vernizPuM2 == null || vernizPuM2 == 0) {
                                  return const Text(
                                    "-",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13),
                                  );
                                }
                                return Text(
                                  "${_formatDecimal(vernizPuM2)} m²",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                );
                              }

                              if (isVernizComum) { // ou isVernizNormal
                                if (vernizComumM2 == null || vernizComumM2 == 0) {
                                  return const Text(
                                    "-",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13),
                                  );
                                }
                                return Text(
                                  "${_formatDecimal(vernizComumM2)} m²",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                );
                              }

                            else if (isMadeiraMacica) {
                              final tamanhoM3 = _calcularVolumeM3Madeira(itemDoc);

                              if (tamanhoM3 <= 0) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }

                              return Text(
                                "${_formatDecimal(tamanhoM3/1000000)} m³",
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              );
                            }

                            if (isFolha) {
                              if (tamanhoFolha ==
                                  null) {
                                return const Text(
                                  "-",
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13),
                                );
                              }
                              return Text(
                                "${_formatDecimal(tamanhoFolha)} m²",
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13),
                              );
                            }

                            if (isPintura) {
                              if (pinturaM2 == null) {
                                return const Text(
                                  "-",
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13),
                                );
                              }
                              return Text(
                                "${_formatDecimal(pinturaM2)} m²",
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13),
                              );
                            }

                            if (isUnidade) {
                              return const Text(
                                "-",
                                textAlign:
                                    TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }

                            final tamanhoValue =
                                itemData['tamanho'];
                            final tamanhoStr =
                                tamanhoValue == null
                                    ? '-'
                                    : tamanhoValue
                                        .toString();
                            return Text(
                              tamanhoStr,
                              textAlign:
                                  TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13),
                            );
                          },
                        ),
                      ),

                      // QUANTIDADE
                      Expanded(
                        flex: 2,
                        child: Builder(
                          builder: (context) {
                            if (isColaFormica) {
                              if (colaLitrosTotal == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                _formatDecimal(colaLitrosTotal),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              );
                            }

                            if (isVernizPu) {
                              if (vernizPuLitros == null || vernizPuLitros == 0) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                _formatDecimal(vernizPuLitros),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              );
                            }

                            if (isVernizComum) {
                              if (vernizComumLitros == null || vernizComumLitros == 0) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                _formatDecimal(vernizComumLitros),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              );
                            }

                            if (isPintura) {
                              if (quantidadePintura == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              } else {
                                return Text(
                                  _formatDecimal(quantidadePintura * 1.20), // 👈 sem unidade
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13),
                                );
                              }
                            }
                            if (isMadeiraMacica) {
                              final tamanhoM3 = _calcularVolumeM3Madeira(itemDoc);

                              if (tamanhoM3 <= 0) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }

                              return Text(
                                _formatDecimal(tamanhoM3/1000000),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              );
                            }

                            if (isColaBranca) {
                              if (litrosColaBranca ==
                                  null) {
                                return const Text(
                                  "-",
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13),
                                );
                              }
                              return Text(
                                _formatDecimal(
                                    litrosColaBranca),
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13),
                              );
                            }
                            if (isFita || isOutros) {
                              if (quantidadefitaitem ==
                                  null) {
                                return const Text(
                                  "-",
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13),
                                );
                              }
                              return Text(
                                _formatDecimal(
                                    quantidadefitaitem),
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13),
                              );
                            }

                            if (isFolha) {
                              if (quantidadeFolha ==
                                  null) {
                                return const Text(
                                  "-",
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13),
                                );
                              }
                              return Text(
                                _formatDecimal(
                                    quantidadeFolha),
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13),
                              );
                            }

                            if (isUnidade) {
                              if (quantidadeUnd ==
                                  null) {
                                return const Text(
                                  "-",
                                  textAlign:
                                      TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13),
                                );
                              }
                              return Text(
                                _formatDecimal(
                                    quantidadeUnd),
                                textAlign:
                                    TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13),
                              );
                            }

                            final q = quantidadeUsada;
                            if (q == null) {
                              return const Text(
                                "-",
                                textAlign:
                                    TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13),
                              );
                            }
                            return Text(
                              _formatDecimal(q),
                              textAlign:
                                  TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13),
                            );
                          },
                        ),
                      ),

                      // PREÇO
                      Expanded(
                        flex: 2,
                        child: _buildPrecoCell(
                          itemData,
                          isFolha: isFolha,
                          isColaFormica: isColaFormica,
                          isColaBranca: isColaBranca,
                          isUnidade: isUnidade,
                          isFita: isFita,
                          isOutros: isOutros,
                          isPintura: isPintura,
                          isMadeiraMacica: isMadeiraMacica,
                          isVernizPu: isVernizPu,
                          isVernizComum: isVernizComum,
                        ),
                      ),

                      // TOTAL
                      Expanded(
                        flex: 2,
                        child: Builder(
                          builder: (context) {
                            // 👇 Pega o nome do item pra detectar "Valor Total"

                            if (isColaFormica) {
                              if (colaLitrosTotal == null || colaPrecoL == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              final total = colaLitrosTotal * colaPrecoL;
                              return Text(
                                "R\$ ${_formatDecimal(total, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            if (isPintura) {
                              if (totalPintura == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                "R\$ ${_formatDecimal(totalPintura * 1.20, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            if (isMadeiraMacica) {
                              final volume = _calcularVolumeM3Madeira(itemDoc);
                              final precoM3 = _toDouble(itemData['precoM3']) ?? 0;

                              if (volume <= 0 || precoM3 <= 0) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }

                              final total = (volume / 1000000) * precoM3;

                              return Text(
                                "R\$ ${_formatDecimal(total, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            if (isColaBranca) {
                              if (totalColaBranca == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                "R\$ ${_formatDecimal(totalColaBranca, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            if (isFita || isOutros) {
                              if (totalFita == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                "R\$ ${_formatDecimal(totalFita, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            if (isFolha) {
                              if (totalFolha == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                "R\$ ${_formatDecimal(totalFolha, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            if (isVernizPu) {
                              if (totalVernizPu == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                "R\$ ${_formatDecimal(totalVernizPu, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            if (isVernizComum) {
                              if (totalVernizComum == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }
                              return Text(
                                "R\$ ${_formatDecimal(totalVernizComum, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            if (isUnidade) {
                              final qtd = _toDouble(itemData['quantidadeUnd']);
                              if (qtd == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }

                              final bool isValorTotal = isUnidade && (itemData['isValorTotal'] == true);

                              final precoTabela = _toDouble(itemData['precoUnidade']);
                              final precoCustom = _toDouble(itemData['precoUnd']);

                              final precoBase = isValorTotal
                                  ? (precoCustom ?? precoTabela)
                                  : precoTabela;

                              if (precoBase == null) {
                                return const Text(
                                  "-",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13),
                                );
                              }

                              final total = qtd * precoBase;

                              return Text(
                                "R\$ ${_formatDecimal(total, dec: 2)}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }

                            final qtd = quantidadeUsada;
                            final preco = precoPorQuantidade;
                            if (qtd == null || preco == null) {
                              return const Text(
                                "-",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13),
                              );
                            }
                            final total = qtd * preco;
                            return Text(
                              "R\$ ${_formatDecimal(total, dec: 2)}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

          const SizedBox(height: 8),

                  // Linha de TOTAL BRUTO (lado direito do móvel)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Total Bruto: R\$ ${_formatDecimal(totalBruto, dec: 2)}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 🔹 Resumo (Frete / Extra / Mão de Obra / Lucro / Total Geral)
                  Align(
                    alignment: Alignment.centerRight,
                    child: StatefulBuilder(
                      builder: (context, setResumoState) {
                        final movelData =
                            doc.data() as Map<String, dynamic>? ?? {};

                        // ---------- valores iniciais ----------
                        final freteCtrl = _getOrCreateResumoController(
                          _freteControllers,
                          doc.id,
                          initialText: movelData['frete']?.toString() ?? '',
                        );
                        final extraCtrl = _getOrCreateResumoController(
                          _almocoControllers,
                          doc.id,
                          initialText: movelData['extra']?.toString() ?? '',
                        );
                        final maoObraCtrl = _getOrCreateResumoController(
                          _maoObraControllers,
                          doc.id,
                          initialText: movelData['maoObra']?.toString() ?? '',
                        );
                        final lucroCtrl = _getOrCreateResumoController(
                          _lucroControllers,
                          doc.id,
                          initialText: movelData['lucroPercentual']?.toString() ?? '',
                        );

                        final obsCtrl = _getOrCreateObsController(
                          doc.id,
                          initial: movelData['obs']?.toString() ?? '',
                        );

                        final frete = _parseResumoDouble(freteCtrl.text);
                        final extra = _parseResumoDouble(extraCtrl.text);
                        final maoObra = _parseResumoDouble(maoObraCtrl.text);
                        final lucro = _parseResumoDouble(lucroCtrl.text);

                        final base = totalBruto + frete + extra + maoObra;
                        final totalGeral = base * (1 + (lucro / 100));

                        final movelRef = doc.reference;

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                        // ===================== OBS (LEFT) =====================
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await _editObsDialog(doc);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black26),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Obs:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // 👇 FIXED HEIGHT + SCROLL
                                  SizedBox(
                                    height: 140, // 🔥 control OBS height here
                                    child: SingleChildScrollView(
                                      child: Text(
                                        obsCtrl.text.trim().isEmpty
                                            ? "Clique para escrever..."
                                            : obsCtrl.text.trim(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: obsCtrl.text.trim().isEmpty
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                              // ===================== RESUMO (RIGHT) =====================
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _linhaResumo(
                                      label: "Frete (R\$)",
                                      controller: freteCtrl,
                                      onChange: () => setResumoState(() {}),
                                      onSave: () async {
                                        await movelRef.update({
                                          'frete': _parseResumoDouble(freteCtrl.text),
                                        });
                                      },
                                    ),
                                    _linhaResumo(
                                      label: "Extra (R\$)",
                                      controller: extraCtrl,
                                      onChange: () => setResumoState(() {}),
                                      onSave: () async {
                                        await movelRef.update({
                                          'extra': _parseResumoDouble(extraCtrl.text),
                                        });
                                      },
                                    ),
                                    _linhaResumo(
                                      label: "Mão de Obra (R\$)",
                                      controller: maoObraCtrl,
                                      onChange: () => setResumoState(() {}),
                                      onSave: () async {
                                        await movelRef.update({
                                          'maoObra': _parseResumoDouble(maoObraCtrl.text),
                                        });
                                      },
                                    ),
                                    _linhaResumo(
                                      label: "(%)",
                                      controller: lucroCtrl,
                                      width: 70,
                                      onChange: () => setResumoState(() {}),
                                      onSave: () async {
                                        await movelRef.update({
                                          'lucroPercentual': _parseResumoDouble(lucroCtrl.text),
                                        });
                                      },
                                    ),

                                    // 🔥 TOTAL GERAL (HERE 👇)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Text(
                                          "Total Geral:",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "R\$ ${_formatDecimal(totalGeral, dec: 2)}",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ]
              );
            }
          )
        ]
      )
    );
  }
}

// ======================================================
//                       HEADER
// ======================================================

extension HeaderExtension on _OrcamentoPageState {
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhoneNarrow = constraints.maxWidth < 420; // tweak if you want

        Widget addressAndPP() {
          final ppWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("PP - ", style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              SizedBox(
                width: isPhoneNarrow ? 110 : 90,
                height: 34,
                child: TextField(
                  controller: ppController,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final txt = value.trim();
                    final parsed = double.tryParse(txt.replaceAll(',', '.'));
                    _orcamentoRef.update({'pp': parsed});
                  },
                ),
              ),
            ],
          );

          // ✅ Desktop/tablet: keep your original Row
          if (!isPhoneNarrow) {
            return Row(
              children: [
                const Expanded(
                  child: Text(
                    "Rua Adel Nogueira Maia, 300 - Messejana",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                ppWidget,
              ],
            );
          }

          // ✅ Phone portrait: stack to avoid overflow (no desktop shrink)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Rua Adel Nogueira Maia, 300 - Messejana",
                style: TextStyle(fontSize: 14),
                softWrap: true,
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: ppWidget),
            ],
          );
        }

        Widget arquitetoRow() {
          final field = SizedBox(
            width: isPhoneNarrow ? double.infinity : larguraArquiteto,
            height: 34,
            child: TextField(
              controller: arquitetoController,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                border: OutlineInputBorder(),
                hintText: "Nome do arquiteto",
              ),
              onChanged: (value) {
                _orcamentoRef.update({'arquiteto': value.trim()});
              },
            ),
          );

          if (!isPhoneNarrow) {
            return Row(
              children: [
                const Text("Arquiteto:", style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                field,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Arquiteto:", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 6),
              field,
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Espart Moveis",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              // ✅ responsive block
              addressAndPP(),

              const SizedBox(height: 6),
              const Text(
                "Telefone: (085)3276-1956 / 3276-5621",
                style: TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Text("Cliente:", style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.clienteNome,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ responsive block
              arquitetoRow(),
            ],
          ),
        );
      },
    );
  }
}

class ResumoMovel extends StatefulWidget {
  final String movelId;
  final double totalBruto;
  final void Function(double totalGeral) onTotalChanged;

  const ResumoMovel({
    super.key,
    required this.movelId,
    required this.totalBruto,
    required this.onTotalChanged,
  });

  @override
  State<ResumoMovel> createState() => _ResumoMovelState();
}

class _ResumoMovelState extends State<ResumoMovel> {
  double frete = 0;
  double almoco = 0;
  double maoObra = 0;
  double lucro = 0;

  String _formatDecimal(num v, {int dec = 2}) => v.toStringAsFixed(dec);

  void _recalcularENotificar() {
    final base = widget.totalBruto + frete + almoco + maoObra;
    final totalGeral = base * (1 + (lucro / 100.0));

    // avisa o pai (OrcamentoPage)
    widget.onTotalChanged(totalGeral);
  }

  @override
  Widget build(BuildContext context) {
    // base = Total Bruto + frete + almoço + mão de obra
    final base = widget.totalBruto + frete + almoco + maoObra;
    final totalGeral = base * (1 + (lucro / 100.0));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ===== TOTAL BRUTO =====
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                "Total Bruto: ",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "R\$ ${_formatDecimal(widget.totalBruto, dec: 2)}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ===== FRETE =====
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Frete (R\$): ",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                height: 30,
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) {
                    setState(() {
                      frete = double.tryParse(
                            value.replaceAll(',', '.'),
                          ) ??
                          0;
                      _recalcularENotificar();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ===== ALMOÇO (Extra) =====
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Extra (R\$): ",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                height: 30,
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) {
                    setState(() {
                      almoco = double.tryParse(
                            value.replaceAll(',', '.'),
                          ) ??
                          0;
                      _recalcularENotificar();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ===== MÃO DE OBRA =====
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Mão de Obra Marceneiro (R\$): ",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                height: 30,
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) {
                    setState(() {
                      maoObra = double.tryParse(
                            value.replaceAll(',', '.'),
                          ) ??
                          0;
                      _recalcularENotificar();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ===== LUCRO % =====
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Lucro (%): ",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                height: 30,
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (value) {
                    setState(() {
                      lucro = double.tryParse(
                            value.replaceAll(',', '.'),
                          ) ??
                          0;
                      _recalcularENotificar();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ===== TOTAL GERAL =====
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                "Total Geral: ",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "R\$ ${_formatDecimal(totalGeral, dec: 2)}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// Classezinha auxiliar (pode ficar no fim do arquivo)
class _PdfLinhaItem {
  final String itemName;
  final String medida;
  final String quantidade;
  final String preco;
  final String total;

  _PdfLinhaItem({
    required this.itemName,
    required this.medida,
    required this.quantidade,
    required this.preco,
    required this.total,
  });
}