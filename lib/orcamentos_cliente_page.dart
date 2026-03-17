import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'orcamento_page.dart';

/// ======================================================
/// CONTADOR GLOBAL DE ORÇAMENTOS
/// ======================================================

Future<int> gerarProximoNumeroOrcamentoGlobal() async {
  final ref = FirebaseFirestore.instance
      .collection('config')
      .doc('contador_orcamentos');

  return FirebaseFirestore.instance.runTransaction((transaction) async {
    final snapshot = await transaction.get(ref);

    int atual = 0;
    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
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

/// ======================================================
/// PÁGINA DE ORÇAMENTOS DO CLIENTE
/// ======================================================

class OrcamentosClientePage extends StatefulWidget {
  final String clienteId;
  final String clienteNome;

  const OrcamentosClientePage({
    super.key,
    required this.clienteId,
    required this.clienteNome,
  });

  @override
  State<OrcamentosClientePage> createState() => _OrcamentosClientePageState();
}

class _OrcamentosClientePageState extends State<OrcamentosClientePage> {
  bool _isFabHovered = false;

  Future<void> _criarNovoOrcamento() async {
    try {
      // 1) Pega o próximo número global de orçamento
      final nextNumero = await gerarProximoNumeroOrcamentoGlobal();

      // 2) Cria o documento do orçamento dentro do cliente
      final novoDoc = await FirebaseFirestore.instance
          .collection('clientes')
          .doc(widget.clienteId)
          .collection('orcamentos')
          .add({
        'numeroOrcamento': nextNumero,
        'createdAt': FieldValue.serverTimestamp(),
        'clienteId': widget.clienteId,
        'clienteNome': widget.clienteNome,
        // Se quiser já criar o campo 'pp' vazio:
        'pp': null,
      });

      if (!mounted) return;

      // 3) Abre a página do orçamento passando o ID e o número
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrcamentoPage(
            clienteId: widget.clienteId,
            clienteNome: widget.clienteNome,
            orcamentoId: novoDoc.id,
            numeroOrcamento: nextNumero,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao criar novo orçamento: $e"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Orçamentos - ${widget.clienteNome}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: "Móveis armazenados",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MoveisArmazenadosPage(
                    clienteId: widget.clienteId,
                    clienteNome: widget.clienteNome,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // FAB estilizado (branco, borda preta, hover) para adicionar orçamento
      floatingActionButton: MouseRegion(
        onEnter: (_) => setState(() => _isFabHovered = true),
        onExit: (_) => setState(() => _isFabHovered = false),
        child: GestureDetector(
          onTap: _criarNovoOrcamento,
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
                        color: Colors.black.withOpacity(0.15),
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

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clientes')
            .doc(widget.clienteId)
            .collection('orcamentos')
            .orderBy('numeroOrcamento', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Erro ao carregar orçamentos."),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("Nenhum orçamento para este cliente."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};

              final numeroOrcamento =
                  (data['numeroOrcamento'] ?? 0).toString();

              final createdAt = data['createdAt'];
              String dataStr = "";
              if (createdAt is Timestamp) {
                final dt = createdAt.toDate();
                dataStr =
                    "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
              }

              // 👇 PP vindo do Firestore
              final String pp =
                  (data['pp'] ?? '').toString().trim();

              // Título que será exibido:
              // se tiver PP, mostra "PP XXXXX"
              // senão, cai no "Orçamento Nº X"
              final String tituloOrcamento =
                  pp.isNotEmpty ? "PP $pp" : "Orçamento Nº $numeroOrcamento";

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Dismissible(
                  key: ValueKey(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.red.withOpacity(0.8),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Remover orçamento"),
                            content: Text(
                              'Deseja remover o orçamento $tituloOrcamento do cliente "${widget.clienteNome}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text("Cancelar"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  "Remover",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (direction) async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('clientes')
                          .doc(widget.clienteId)
                          .collection('orcamentos')
                          .doc(doc.id)
                          .delete();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Orçamento $tituloOrcamento removido de "${widget.clienteNome}".',
                          ),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Erro ao remover orçamento: $e"),
                        ),
                      );
                    }
                  },
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrcamentoPage(
                            clienteId: widget.clienteId,
                            clienteNome: widget.clienteNome,
                            orcamentoId: doc.id,
                            numeroOrcamento:
                                int.tryParse(numeroOrcamento) ?? 1,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.black87),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tituloOrcamento,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (dataStr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Data: $dataStr",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ======================================================
/// PÁGINA DE MÓVEIS ARMAZENADOS
/// ======================================================

class MoveisArmazenadosPage extends StatelessWidget {
  final String clienteId;
  final String clienteNome;

  const MoveisArmazenadosPage({
    super.key,
    required this.clienteId,
    required this.clienteNome,
  });

  @override
  Widget build(BuildContext context) {
    final modelosRef = FirebaseFirestore.instance
        .collection('clientes')
        .doc(clienteId)
        .collection('moveis_armazenados');

    return Scaffold(
      appBar: AppBar(
        title: Text("Móveis armazenados - $clienteNome"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: modelosRef.orderBy('nome', descending: false).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Erro ao carregar móveis armazenados."),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("Nenhum móvel armazenado para este cliente."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};

              final nome = data['nome'] as String? ?? "(sem nome)";
              final numOrig = data['numeroOrcamentoOriginal'];
              final numeroOrigStr =
                  numOrig == null ? "-" : numOrig.toString();

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(
                    nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    "Orig. Orçamento Nº $numeroOrigStr",
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: "Adicionar em um orçamento",
                    onPressed: () {
                      _showAdicionarMovelEmOrcamentoDialog(
                        context,
                        clienteId,
                        doc,
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAdicionarMovelEmOrcamentoDialog(
    BuildContext context,
    String clienteId,
    DocumentSnapshot movelModeloDoc,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _AdicionarMovelDialog(
          clienteId: clienteId,
          movelModeloDoc: movelModeloDoc,
          parentContext: context,
        );
      },
    );
  }
}

/// ======================================================
/// DIALOG: Escolher em qual orçamento inserir o móvel
/// ======================================================

class _AdicionarMovelDialog extends StatefulWidget {
  final String clienteId;
  final DocumentSnapshot movelModeloDoc;
  final BuildContext parentContext;

  const _AdicionarMovelDialog({
    required this.clienteId,
    required this.movelModeloDoc,
    required this.parentContext,
  });

  @override
  State<_AdicionarMovelDialog> createState() => _AdicionarMovelDialogState();
}

class _AdicionarMovelDialogState extends State<_AdicionarMovelDialog> {
  String? _orcamentoSelecionadoId;
  DocumentSnapshot? _orcamentoSelecionadoDoc;

  @override
  Widget build(BuildContext context) {
    final orcamentosRef = FirebaseFirestore.instance
        .collection('clientes')
        .doc(widget.clienteId)
        .collection('orcamentos')
        .orderBy('numeroOrcamento', descending: false);

    return AlertDialog(
      title: const Text("Adicionar móvel em um orçamento"),
      content: SizedBox(
        width: 380,
        height: 260,
        child: FutureBuilder<QuerySnapshot>(
          future: orcamentosRef.get(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text("Erro ao carregar orçamentos."),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text("Nenhum orçamento encontrado para este cliente."),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final numero = data['numeroOrcamento'] ?? 0;
                final createdAt = data['createdAt'];
                String dataStr = "";

                if (createdAt is Timestamp) {
                  final dt = createdAt.toDate();
                  dataStr =
                      "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
                }

                return RadioListTile<String>(
                  value: doc.id,
                  groupValue: _orcamentoSelecionadoId,
                  title: Text("Orçamento Nº $numero"),
                  subtitle: dataStr.isNotEmpty
                      ? Text(
                          "Data: $dataStr",
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                  onChanged: (value) {
                    setState(() {
                      _orcamentoSelecionadoId = value;
                      _orcamentoSelecionadoDoc = doc;
                    });
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        TextButton(
          onPressed: _orcamentoSelecionadoDoc == null
              ? null
              : () async {
                  final orcamentoDocSelecionado = _orcamentoSelecionadoDoc!;

                  Navigator.of(context).pop();

                  try {
                    await moverModeloParaOrcamento(
                      widget.parentContext,
                      widget.clienteId,
                      widget.movelModeloDoc,
                      orcamentoDocSelecionado,
                    );

                    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                      const SnackBar(
                        content:
                            Text("Móvel adicionado ao orçamento com sucesso."),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                      SnackBar(
                        content: Text("Erro ao adicionar móvel: $e"),
                      ),
                    );
                  }
                },
          child: const Text(
            "Adicionar",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// ======================================================
/// FUNÇÃO: Copiar o móvel armazenado para um orçamento
/// ======================================================

Future<void> moverModeloParaOrcamento(
  BuildContext context,
  String clienteId,
  DocumentSnapshot movelModeloDoc,
  DocumentSnapshot orcamentoDoc,
) async {
  final db = FirebaseFirestore.instance;

  final movelData = movelModeloDoc.data() as Map<String, dynamic>? ?? {};
  final nomeMovel = movelData['nome'] as String? ?? "(sem nome)";

  final orcData = orcamentoDoc.data() as Map<String, dynamic>? ?? {};
  final numeroOrcamento = orcData['numeroOrcamento'] ?? 0;

  final moveisRef = db.collection('moveis');
  final novoMovelRef = moveisRef.doc();

  final novoData = Map<String, dynamic>.from(movelData);

  novoData['numeroOrcamento'] = numeroOrcamento;
  novoData['clienteId'] = clienteId;
  novoData['createdAt'] = FieldValue.serverTimestamp();

  novoData.remove('numeroOrcamentoOriginal');
  novoData.remove('armazenadoEm');

  await novoMovelRef.set(novoData);

  final itensSnap =
      await movelModeloDoc.reference.collection('itens').get();

  for (final item in itensSnap.docs) {
    await novoMovelRef.collection('itens').add(item.data());
  }

  for (final item in itensSnap.docs) {
    await item.reference.delete();
  }
  await movelModeloDoc.reference.delete();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Móvel "$nomeMovel" adicionado ao Orçamento Nº $numeroOrcamento.',
      ),
    ),
  );
}