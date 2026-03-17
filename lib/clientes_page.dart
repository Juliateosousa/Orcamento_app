import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'orcamentos_cliente_page.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";

  // 👇 controla o hover do botão de adicionar cliente
  bool _isFabHover = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clientes"),
      ),

      // ✅ FAB customizado com hover
      floatingActionButton: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() {
            _isFabHover = true;
          });
        },
        onExit: (_) {
          setState(() {
            _isFabHover = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _isFabHover ? Colors.black : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1.2),
          ),
          child: IconButton(
            onPressed: () {
              _abrirDialogNovoCliente(context);
            },
            icon: Icon(
              Icons.add,
              color: _isFabHover ? Colors.white : Colors.black,
              size: 28,
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // 🔎 Barra de busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: "Buscar cliente",
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Lista de clientes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clientes')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text("Erro ao carregar clientes"),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final allDocs = snapshot.data!.docs;

                // 🔍 filtro pelo nome digitado
                final filteredDocs = allDocs.where((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>? ?? {};
                  final nome = (data['nome'] ?? '') as String;
                  if (_searchTerm.isEmpty) return true;
                  return nome.toLowerCase().contains(_searchTerm);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text("Nenhum cliente encontrado"),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final cliente = filteredDocs[index];
                    final data =
                        cliente.data() as Map<String, dynamic>? ?? {};

                    final nome = (data['nome'] ?? '') as String;
                    final telefone =
                        (data['telefone'] ?? '') as String;
                    final arquiteto =
                        (data['arquiteto'] ?? '') as String;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Dismissible(
                        key: ValueKey(cliente.id),
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
                                  title: const Text("Remover cliente"),
                                  content: Text(
                                    'Deseja remover o cliente "$nome"? Isso apagará todos os orçamentos dele.',
                                  ),
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
                            await FirebaseFirestore.instance
                                .collection('clientes')
                                .doc(cliente.id)
                                .delete();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Cliente "$nome" removido.'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Erro ao remover cliente: $e'),
                              ),
                            );
                          }
                        },

                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrcamentosClientePage(
                                  clienteId: cliente.id,
                                  clienteNome: nome,
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
                                  nome,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                if (arquiteto.isNotEmpty)
                                  Text(
                                    "Arquiteto: $arquiteto",
                                    style: const TextStyle(fontSize: 13),
                                  ),
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
          ),
        ],
      ),
    );
  }

  // Dialog de criação de cliente
  void _abrirDialogNovoCliente(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final arquitetoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Novo Cliente"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: "Nome"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                final nome = nomeCtrl.text.trim();
                if (nome.isEmpty) return;

                await FirebaseFirestore.instance.collection('clientes').add({
                  'nome': nome,
                  'telefone': telefoneCtrl.text.trim(),
                  'arquiteto': arquitetoCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });

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
}