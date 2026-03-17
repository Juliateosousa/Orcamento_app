import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItensPage extends StatelessWidget {
  const ItensPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, // Folha, Madeira Maciça, Litro, Metro, Unidade
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Itens"),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: "Folha"),
              Tab(text: "Litro"),
              Tab(text: "Metro"),
              Tab(text: "Unidade"),
              Tab(text: "Madeira Maciça"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ItensFolhaView(),
            _ItensLitroView(),
            _ItensMetroView(),
            _ItensUnidadeView(),
            _ItensMadeiraMacicaView(),
          ],
        ),
      ),
    );
  }
}

// =====================================================
//          CARD EM TABELINHA PARA FOLHA (MDF, etc.)
// =====================================================

class _FolhaItemRowCard extends StatelessWidget {
  final String nome;
  final String precoText;
  final String areaText;
  final String perdaText;
  final VoidCallback onTap;

  const _FolhaItemRowCard({
    required this.nome,
    required this.precoText,
    required this.areaText,
    required this.perdaText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.2);
    final bgColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.06);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Nome do item (lado esquerdo)
            Expanded(
              flex: 2,
              child: Text(
                nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // "Tabela" do lado direito
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _smallColumn("Preço", precoText),
                  _smallColumn("Área", areaText),
                  _smallColumn("Perda", perdaText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _smallColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =====================================================
//      CARD ESPECIAL PARA COLAS (MOSTRA 1 OU 2 COLUNAS)
// =====================================================

class _ColaItemRowCard extends StatelessWidget {
  final String nome;
  final bool hasPrecoL;
  final bool hasLm2;
  final String precoLText;
  final String lm2Text;
  final VoidCallback? onTap;

  const _ColaItemRowCard({
    required this.nome,
    required this.hasPrecoL,
    required this.hasLm2,
    required this.precoLText,
    required this.lm2Text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.2);
    final bgColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.06);

    // Monta as colunas da direita como Columns normais
    final List<Widget> rightColumns = [];

    if (hasPrecoL) {
      rightColumns.add(_buildColumn("Preço / L", precoLText));
    }
    if (hasLm2) {
      rightColumns.add(_buildColumn("L/m²", lm2Text));
    }
    if (rightColumns.isEmpty) {
      rightColumns.add(_buildColumn("Valor", "-"));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Nome da cola (esquerda)
            Expanded(
              flex: 2,
              child: Text(
                nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Parte da direita (Preço/L, L/m²)
            Expanded(
              flex: 2,
              child: rightColumns.length == 1
                  // Só um valor -> usa só a Column
                  ? rightColumns.first
                  // Dois valores -> Row com as duas Columns dentro de Expanded
                  : Row(
                      children: rightColumns
                          .map((w) => Expanded(child: w))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =====================================================
//    CARD SIMPLES PARA LITRO (TINTAS / VERNIZ / METRO)
// =====================================================

class _LitroItemRowCard extends StatelessWidget {
  final String nome;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _LitroItemRowCard({
    required this.nome,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.2);
    final bgColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.06);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
//    CARD SIMPLES PARA METRO (PREÇO + METRAGEM)
// =====================================================

class _MetroItemRowCard extends StatelessWidget {
  final String nome;
  final String precoText;
  final String metragemText;
  final VoidCallback onTap;

  const _MetroItemRowCard({
    required this.nome,
    required this.precoText,
    required this.metragemText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.2);
    final bgColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.06);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.center,
                child: _smallColumn("Preço/m", precoText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _smallColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =====================================================
//    CARD SIMPLES PARA UNIDADE (PREÇO POR UND)
// =====================================================

class _UnidadeItemRowCard extends StatelessWidget {
  final String nome;
  final String precoText;
  final VoidCallback onTap;

  const _UnidadeItemRowCard({
    required this.nome,
    required this.precoText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.2);
    final bgColor =
        Theme.of(context).colorScheme.primary.withOpacity(0.06);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Preço / Und",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    precoText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
//                   MADEIRA MACIÇA
// =====================================================
class _ItensMadeiraMacicaView extends StatefulWidget {
  const _ItensMadeiraMacicaView();

  @override
  State<_ItensMadeiraMacicaView> createState() =>
      _ItensMadeiraMacicaViewState();
}

class _ItensMadeiraMacicaViewState extends State<_ItensMadeiraMacicaView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _formatPrecoM3(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "R\$ ${d.toStringAsFixed(2)}/m³";
  }

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

  Future<bool> _confirmDelete(BuildContext context, String nome) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remover item"),
        content: Text('Deseja remover o item "$nome"?'),
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
    );

    return result ?? false; // 👈 GARANTE QUE SEMPRE VOLTA UM BOOL
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Novo Item"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Nome do item",
              hintText: "Ex: Madeira X",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                final nome = nameController.text.trim();

                if (nome.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('items').add({
                    'name': nome,
                    'unitType': 'madeiraMacica', // ✅ corrige tipo
                    'subcategory': null,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Item "$nome" adicionado com sucesso.'),
                      ),
                    );
                  }

                  Navigator.pop(ctx);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Erro ao salvar item: $e"),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                "Adicionar",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final nome = data['name'] as String? ?? "(sem nome)";

    final precoController = TextEditingController(
      text: data['precoM3']?.toString() ?? "",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nome),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: precoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Preço por m³ (R\$)",
                hintText: "Ex: 2500.00",
                border: OutlineInputBorder(),
              ),
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
              double? parse(String t) =>
                  double.tryParse(t.replaceAll(',', '.'));

              final preco = parse(precoController.text.trim());

              try {
                await doc.reference.update({
                  'precoM3': preco,
                });
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Preço atualizado para "$nome".',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erro ao salvar dados do item: $e"),
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

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('unitType', isEqualTo: 'madeiraMacica');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: "Buscar item (Madeira Maciça)",
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Row(
                children: [
                  const Text(
                    "Madeira Maciça",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: "Adicionar item em Madeira Maciça",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      "Erro ao carregar itens: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Text(
                      "Carregando itens...",
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Text(
                      "Nenhum item cadastrado ainda.",
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  final docs = snapshot.data!.docs.toList()
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

                  final filteredDocs = docs.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>? ?? {};
                    final nome = (data['name'] ?? '') as String;
                    if (_searchTerm.isEmpty) return true;
                    return nome.toLowerCase().contains(_searchTerm);
                  }).toList();

                  return Column(
                    children: [
                      for (final doc in filteredDocs) ...[
                        Builder(
                          builder: (ctx) {
                            final data =
                                doc.data() as Map<String, dynamic>? ?? {};
                            final nome =
                                data['name'] as String? ?? "(sem nome)";
                            final precoM3 = data['precoM3'];
                            final precoText = _formatPrecoM3(precoM3);

                            const metragemText = "-";

                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8.0),
                              child: Dismissible(
                                key: ValueKey(doc.id),
                                direction:
                                    DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  color:
                                      Colors.red.withOpacity(0.8),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (direction) =>
                                    _confirmDelete(context, nome),
                                onDismissed: (direction) async {
                                  try {
                                    await doc.reference.delete();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Item "$nome" removido.'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Erro ao remover item "$nome": $e'),
                                      ),
                                    );
                                  }
                                },
                                child: _MetroItemRowCard(
                                  nome: nome,
                                  precoText: precoText,
                                  metragemText: metragemText,
                                  onTap: () =>
                                      _showEditDialog(context, doc),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
//                       FOLHA
// =====================================================

class _ItensFolhaView extends StatefulWidget {
  const _ItensFolhaView();

  @override
  State<_ItensFolhaView> createState() => _ItensFolhaViewState();
}

class _ItensFolhaViewState extends State<_ItensFolhaView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";

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
    return Column(
      children: [
        // 🔎 busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: "Buscar item (Folha)",
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _FolhaCategoriaSection(
                title: "Compensado",
                subcategoryKey: "compensado",
                searchTerm: _searchTerm,
              ),
              _FolhaCategoriaSection(
                title: "Formica",
                subcategoryKey: "formica",
                searchTerm: _searchTerm,
              ),
              _FolhaCategoriaSection(
                title: "MDF",
                subcategoryKey: "mdf",
                searchTerm: _searchTerm,
              ),
              _FolhaCategoriaSection(
                title: "Lâmina",
                subcategoryKey: "lamina",
                searchTerm: _searchTerm,
              ),
              _FolhaCategoriaSection(
                title: "Manta",
                subcategoryKey: "manta",
                searchTerm: _searchTerm,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FolhaCategoriaSection extends StatelessWidget {
  final String title;
  final String subcategoryKey; // "compensado" | "formica" | "mdf" | "lamina" | "manta"
  final String searchTerm;

  const _FolhaCategoriaSection({
    required this.title,
    required this.subcategoryKey,
    required this.searchTerm,
  });

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _formatPreco(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "R\$ ${d.toStringAsFixed(2)}";
  }

  String _formatArea(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "${d.toStringAsFixed(2)} m²";
  }

  String _formatPerda(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "${d.toStringAsFixed(1)}%";
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Novo item em $title"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Nome do item",
            hintText: "Ex: MDF __mm _ Faces Ultra",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('items').add({
        'name': name,
        'unitType': 'folha',
        'subcategory': subcategoryKey,
        'precoFolha': null,
        'areaFolha': null,
        'taxaPerca': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item "$name" adicionado em $title')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar item: $e')),
      );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final precoController = TextEditingController(
      text: data['precoFolha']?.toString() ?? "",
    );
    final areaController = TextEditingController(
      text: data['areaFolha']?.toString() ?? "",
    );
    final perdaController = TextEditingController(
      text: data['taxaPerca']?.toString() ?? "",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(data['name'] ?? "Item"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: precoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Preço da Folha (R\$)",
                  hintText: "Ex: 350.00",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: areaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Área da Folha (m²)",
                  hintText: "Ex: 2.80",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: perdaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Taxa de Perca (%)",
                  hintText: "Ex: 10",
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
              double? parse(String text) =>
                  double.tryParse(text.replaceAll(',', '.'));

              final preco = parse(precoController.text);
              final area = parse(areaController.text);
              final perda = parse(perdaController.text);

              try {
                await doc.reference.update({
                  'precoFolha': preco,
                  'areaFolha': area,
                  'taxaPerca': perda,
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao salvar: $e')),
                );
              }

              // ignore: use_build_context_synchronously
              Navigator.pop(ctx);
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

  Future<bool> _confirmDelete(BuildContext context, String nome) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Remover item"),
            content: Text('Deseja remover o item "$nome"?'),
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
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('unitType', isEqualTo: 'folha')
        .where('subcategory', isEqualTo: subcategoryKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // título + botão adicionar
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showAddItemDialog(context),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: "Adicionar item em $title",
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Erro ao carregar: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Carregando...",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "Nenhum item cadastrado ainda.",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final da = (a.data() as Map<String, dynamic>? ?? {});
                final db = (b.data() as Map<String, dynamic>? ?? {});
                final na = (da['name'] ?? '') as String;
                final nb = (db['name'] ?? '') as String;
                return na.toLowerCase().compareTo(nb.toLowerCase());
              });

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final nome = (data['name'] ?? '') as String;
              if (searchTerm.isEmpty) return true;
              return nome.toLowerCase().contains(searchTerm);
            }).toList();

            return Column(
              children: [
                for (final doc in filteredDocs) ...[
                  Builder(
                    builder: (ctx) {
                      final data =
                          doc.data() as Map<String, dynamic>? ?? {};
                      final nome = data['name'] as String? ?? "(sem nome)";
                      final preco = _formatPreco(data['precoFolha']);
                      final area = _formatArea(data['areaFolha']);
                      final perda = _formatPerda(data['taxaPerca']);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.red.withOpacity(0.8),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) =>
                              _confirmDelete(context, nome),
                          onDismissed: (direction) async {
                            try {
                              await doc.reference.delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Item "$nome" removido de $title.'),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Erro ao remover item: $e"),
                                ),
                              );
                            }
                          },
                          child: _FolhaItemRowCard(
                            nome: nome,
                            precoText: preco,
                            areaText: area,
                            perdaText: perda,
                            onTap: () => _showEditDialog(context, doc),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// =====================================================
//                       LITRO
// =====================================================

class _ItensLitroView extends StatefulWidget {
  const _ItensLitroView();

  @override
  State<_ItensLitroView> createState() => _ItensLitroViewState();
}

class _ItensLitroViewState extends State<_ItensLitroView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";

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
    return Column(
      children: [
        // 🔎 busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: "Buscar item (Litro)",
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _TintasSection(searchTerm: _searchTerm),
              _VernizSection(searchTerm: _searchTerm),
              _ColasSection(searchTerm: _searchTerm),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------ TINTAS ------------

class _TintasSection extends StatelessWidget {
  final String searchTerm;

  const _TintasSection({required this.searchTerm});

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _formatPrecoM2(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "R\$ ${d.toStringAsFixed(2)} / m²";
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nova Tinta"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Nome da tinta",
            hintText: "Ex: Pintura a Laca",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('items').add({
        'name': name,
        'unitType': 'litro',
        'subcategory': 'tintas',
        'precoM2': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tinta "$name" adicionada.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar tinta: $e')),
      );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final nome = data['name'] as String? ?? "(sem nome)";
    final controller = TextEditingController(
      text: data['precoM2']?.toString() ?? "",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nome),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Preço por m² (R\$)",
            hintText: "Ex: 150.00",
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

              final preco = parse(controller.text.trim());

              try {
                await doc.reference.update({'precoM2': preco});
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Preço atualizado para "$nome".'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text("Erro ao salvar preço da tinta: $e"),
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

  Future<bool> _confirmDelete(BuildContext context, String nome) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Remover tinta"),
            content: Text('Deseja remover a tinta "$nome"?'),
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
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('unitType', isEqualTo: 'litro')
        .where('subcategory', isEqualTo: 'tintas');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Tintas",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showAddItemDialog(context),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: "Adicionar tinta",
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                "Erro ao carregar tintas: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text(
                "Carregando tintas...",
                style: TextStyle(color: Colors.grey),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text(
                "Nenhuma tinta cadastrada ainda.",
                style: TextStyle(color: Colors.grey),
              );
            }

            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final da = (a.data() as Map<String, dynamic>? ?? {});
                final db = (b.data() as Map<String, dynamic>? ?? {});
                final na = (da['name'] ?? '') as String;
                final nb = (db['name'] ?? '') as String;
                return na.toLowerCase().compareTo(nb.toLowerCase());
              });

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final nome = (data['name'] ?? '') as String;
              if (searchTerm.isEmpty) return true;
              return nome.toLowerCase().contains(searchTerm);
            }).toList();

            return Column(
              children: [
                for (final doc in filteredDocs) ...[
                  Builder(
                    builder: (ctx) {
                      final data =
                          doc.data() as Map<String, dynamic>? ?? {};
                      final nome = data['name'] as String? ?? "(sem nome)";
                      final preco = _formatPrecoM2(data['precoM2']);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.red.withOpacity(0.8),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) =>
                              _confirmDelete(context, nome),
                          onDismissed: (direction) async {
                            try {
                              await doc.reference.delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Tinta "$nome" removida.'),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Erro ao remover tinta: $e"),
                                ),
                              );
                            }
                          },
                          child: _LitroItemRowCard(
                            nome: nome,
                            label: "Preço por m²",
                            value: preco,
                            onTap: () => _showEditDialog(context, doc),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ------------ VERNIZ ------------

class _VernizSection extends StatelessWidget {
  final String searchTerm;

  const _VernizSection({required this.searchTerm});

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _formatPrecoM2(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "R\$ ${d.toStringAsFixed(2)} / m²";
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Novo Verniz"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Nome do verniz",
            hintText: "Ex: Verniz PU",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('items').add({
        'name': name,
        'unitType': 'litro',
        'subcategory': 'verniz',
        'precoM2': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verniz "$name" adicionada.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar verniz: $e')),
      );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final nome = data['name'] as String? ?? "(sem nome)";
    final controller = TextEditingController(
      text: data['precoM2']?.toString() ?? "",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nome),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Preço por m² (R\$)",
            hintText: "Ex: 150.00",
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

              final preco = parse(controller.text.trim());

              try {
                await doc.reference.update({'precoM2': preco});
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Preço atualizado para "$nome".'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text("Erro ao salvar preço do verniz: $e"),
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

  Future<bool> _confirmDelete(BuildContext context, String nome) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Remover verniz"),
            content: Text('Deseja remover o verniz "$nome"?'),
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
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('unitType', isEqualTo: 'litro')
        .where('subcategory', isEqualTo: 'verniz');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Verniz",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showAddItemDialog(context),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: "Adicionar verniz",
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                "Erro ao carregar vernizes: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text(
                "Carregando vernizes...",
                style: TextStyle(color: Colors.grey),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text(
                "Nenhum verniz cadastrado ainda.",
                style: TextStyle(color: Colors.grey),
              );
            }

            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final da = (a.data() as Map<String, dynamic>? ?? {});
                final db = (b.data() as Map<String, dynamic>? ?? {});
                final na = (da['name'] ?? '') as String;
                final nb = (db['name'] ?? '') as String;
                return na.toLowerCase().compareTo(nb.toLowerCase());
              });

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final nome = (data['name'] ?? '') as String;
              if (searchTerm.isEmpty) return true;
              return nome.toLowerCase().contains(searchTerm);
            }).toList();

            return Column(
              children: [
                for (final doc in filteredDocs) ...[
                  Builder(
                    builder: (ctx) {
                      final data =
                          doc.data() as Map<String, dynamic>? ?? {};
                      final nome = data['name'] as String? ?? "(sem nome)";
                      final preco = _formatPrecoM2(data['precoM2']);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.red.withOpacity(0.8),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) =>
                              _confirmDelete(context, nome),
                          onDismissed: (direction) async {
                            try {
                              await doc.reference.delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Verniz "$nome" removido.'),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Erro ao remover verniz: $e"),
                                ),
                              );
                            }
                          },
                          child: _LitroItemRowCard(
                            nome: nome,
                            label: "Preço por m²",
                            value: preco,
                            onTap: () => _showEditDialog(context, doc),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ------------ COLAS (COM CHECKBOXES) ------------

class _ColasSection extends StatelessWidget {
  final String searchTerm;

  const _ColasSection({required this.searchTerm});

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _formatPrecoL(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "R\$ ${d.toStringAsFixed(2)} / L";
  }

  String _formatLm2(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "${d.toStringAsPrecision(3)} L/m²";
  }

  Future<void> _showAddColaDialog(BuildContext context) async {
    final nameController = TextEditingController();
    bool hasPrecoL = true;
    bool hasLm2 = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text("Nova Cola"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Nome da cola",
                      hintText: "Ex: Cola Branca, Cola Formica...",
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hasPrecoL,
                    onChanged: (v) {
                      setState(() {
                        hasPrecoL = v ?? false;
                      });
                    },
                    title: const Text("Usar Preço por L"),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hasLm2,
                    onChanged: (v) {
                      setState(() {
                        hasLm2 = v ?? false;
                      });
                    },
                    title: const Text("Usar L/m²"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar"),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty || (!hasPrecoL && !hasLm2)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Informe um nome e marque pelo menos uma opção.",
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx, {
                      'name': name,
                      'hasPrecoL': hasPrecoL,
                      'hasLm2': hasLm2,
                    });
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

    if (result == null) return;

    final String name = result['name'] as String;
    final bool selectedPrecoL = result['hasPrecoL'] as bool;
    final bool selectedLm2 = result['hasLm2'] as bool;

    try {
      await FirebaseFirestore.instance.collection('items').add({
        'name': name,
        'unitType': 'litro',
        'subcategory': 'colas',
        'hasPrecoL': selectedPrecoL,
        'hasLm2': selectedLm2,
        'precoL': null,
        'lm2': null,
        'usaLm2Separado': false, // 👈 NOVO
        'lm2Mdf': null, // 👈 NOVO
        'lm2Formica': null, // 👈 NOVO
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cola "$name" adicionada.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar cola: $e')),
      );
    }
  }

  Future<void> _showEditColaDialog(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final name = data['name'] as String? ?? "(sem nome)";

    final bool hasPrecoL = (data['hasPrecoL'] as bool?) ?? false;
    final bool hasLm2 = (data['hasLm2'] as bool?) ?? false;

    final isColaFormica = name.toLowerCase() == 'cola formica';

    final precoLController = TextEditingController(
      text: data['precoL']?.toString() ?? "",
    );
    final lm2Controller = TextEditingController(
      text: data['lm2']?.toString() ?? "",
    );

    bool usaLm2Separado = (data['usaLm2Separado'] as bool?) ?? false;
    final lm2MdfController = TextEditingController(
      text: data['lm2Mdf']?.toString() ?? "",
    );
    final lm2FormicaController = TextEditingController(
      text: data['lm2Formica']?.toString() ?? "",
    );

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(name),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPrecoL) ...[
                      TextField(
                        controller: precoLController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: "Preço por L (R\$)",
                          hintText: "Ex: 45.90",
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (hasLm2) ...[
                      if (isColaFormica) ...[
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: usaLm2Separado,
                          onChanged: (v) {
                            setState(() {
                              usaLm2Separado = v ?? false;
                            });
                          },
                          title: const Text(
                            "Usar L/m² separado para MDF e Formica",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (usaLm2Separado) ...[
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "L/m² (MDF):",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: lm2MdfController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 8,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "L/m² (Formica):",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: lm2FormicaController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 8,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          TextField(
                            controller: lm2Controller,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration: const InputDecoration(
                              labelText: "L/m²",
                              hintText:
                                  "Ex: 0.7 (por exemplo 3.5L / 5.03m² ≈ 0.696)",
                            ),
                          ),
                        ],
                      ] else ...[
                        TextField(
                          controller: lm2Controller,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                            labelText: "L/m²",
                            hintText:
                                "Ex: 0.7 (por exemplo 3.5L / 5.03m² ≈ 0.696)",
                          ),
                        ),
                      ],
                    ],
                    if (!hasPrecoL && !hasLm2) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "Este item não foi configurado com Preço/L nem L/m².",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
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
                    double? parse(String text) =>
                        double.tryParse(text.replaceAll(',', '.'));

                    final precoL = hasPrecoL
                        ? parse(precoLController.text.trim())
                        : null;

                    double? lm2;
                    double? lm2Mdf;
                    double? lm2Formica;

                    bool finalUsaLm2Separado = false;

                    if (hasLm2) {
                      if (isColaFormica && usaLm2Separado) {
                        lm2Mdf = parse(lm2MdfController.text.trim());
                        lm2Formica =
                            parse(lm2FormicaController.text.trim());
                        lm2 = null;
                        finalUsaLm2Separado = true;
                      } else {
                        lm2 = parse(lm2Controller.text.trim());
                        lm2Mdf = null;
                        lm2Formica = null;
                        finalUsaLm2Separado = false;
                      }
                    }

                    try {
                      await doc.reference.update({
                        'precoL': precoL,
                        'lm2': lm2,
                        'usaLm2Separado': finalUsaLm2Separado,
                        'lm2Mdf': lm2Mdf,
                        'lm2Formica': lm2Formica,
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Dados atualizados para "$name".'),
                          ),
                        );
                      }
                      // ignore: use_build_context_synchronously
                      Navigator.pop(ctx);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Erro ao salvar dados da cola: $e"),
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

  Future<bool> _confirmDelete(BuildContext context, String nome) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Remover cola"),
            content: Text('Deseja remover a cola "$nome"?'),
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
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('unitType', isEqualTo: 'litro')
        .where('subcategory', isEqualTo: 'colas');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Colas",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showAddColaDialog(context),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: "Adicionar cola",
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                "Erro ao carregar colas: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text(
                "Carregando colas...",
                style: TextStyle(color: Colors.grey),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text(
                "Nenhuma cola cadastrada ainda.",
                style: TextStyle(color: Colors.grey),
              );
            }

            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final da = (a.data() as Map<String, dynamic>? ?? {});
                final db = (b.data() as Map<String, dynamic>? ?? {});
                final na = (da['name'] ?? '') as String;
                final nb = (db['name'] ?? '') as String;
                return na.toLowerCase().compareTo(nb.toLowerCase());
              });

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final nome = (data['name'] ?? '') as String;
              if (searchTerm.isEmpty) return true;
              return nome.toLowerCase().contains(searchTerm);
            }).toList();

            return Column(
              children: [
                for (final doc in filteredDocs) ...[
                  Builder(
                    builder: (ctx) {
                      final data =
                          doc.data() as Map<String, dynamic>? ?? {};
                      final nome = data['name'] as String? ?? "(sem nome)";
                      final hasPrecoL =
                          (data['hasPrecoL'] as bool?) ?? false;
                      final hasLm2 =
                          (data['hasLm2'] as bool?) ?? false;

                      final precoLText =
                          hasPrecoL ? _formatPrecoL(data['precoL']) : "-";

                      String lm2Text = "-";
                      if (hasLm2) {
                        final nomeLower = nome.toLowerCase();
                        if (nomeLower == 'cola formica') {
                          final lm2Mdf = _toDouble(data['lm2Mdf']);
                          final lm2Formica =
                              _toDouble(data['lm2Formica']);
                          final usaSeparado =
                              data['usaLm2Separado'] == true;

                          if (usaSeparado &&
                              (lm2Mdf != null || lm2Formica != null)) {
                            final mdfStr = lm2Mdf != null
                                ? "${lm2Mdf.toStringAsPrecision(3)} MDF"
                                : "";
                            final formStr = lm2Formica != null
                                ? "${lm2Formica.toStringAsPrecision(3)} Formica"
                                : "";
                            lm2Text = [mdfStr, formStr]
                                .where((s) => s.isNotEmpty)
                                .join(" / ");
                          } else {
                            lm2Text = _formatLm2(data['lm2']);
                          }
                        } else {
                          lm2Text = _formatLm2(data['lm2']);
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.red.withOpacity(0.8),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) =>
                              _confirmDelete(context, nome),
                          onDismissed: (direction) async {
                            try {
                              await doc.reference.delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Cola "$nome" removida.'),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Erro ao remover cola: $e"),
                                ),
                              );
                            }
                          },
                          child: _ColaItemRowCard(
                            nome: nome,
                            hasPrecoL: hasPrecoL,
                            hasLm2: hasLm2,
                            precoLText: precoLText,
                            lm2Text: lm2Text,
                            onTap: () => _showEditColaDialog(
                              context,
                              doc,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// =====================================================
//                       METRO
// =====================================================

class _ItensMetroView extends StatefulWidget {
  const _ItensMetroView();

  @override
  State<_ItensMetroView> createState() => _ItensMetroViewState();
}

class _ItensMetroViewState extends State<_ItensMetroView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: "Buscar item (Metro)",
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _MetroCategoriaSection(
                title: "Fitas",
                subcategoryKey: "fita",
                searchTerm: _searchTerm,
              ),
              _MetroCategoriaSection(
                title: "Outros",
                subcategoryKey: "outros",
                searchTerm: _searchTerm,),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetroCategoriaSection extends StatelessWidget {
  final String title;
  final String subcategoryKey;
  final String searchTerm;

  const _MetroCategoriaSection({
    required this.title,
    required this.subcategoryKey,
    required this.searchTerm,
  });

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _formatPreco(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "R\$ ${d.toStringAsFixed(2)}";
  }

  String _formatMetragem(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "${d.toStringAsFixed(2)} m";
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Novo item em $title"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Nome do item",
            hintText: "Ex: Fita Tal",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              "Salvar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('items').add({
        'name': name,
        'unitType': 'metro',
        'subcategory': subcategoryKey,
        'precoMetro': null,
        'metragem': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item "$name" adicionado em $title')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar item: $e')),
      );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final nome = data['name'] as String? ?? "(sem nome)";
    final precoController = TextEditingController(
      text: data['precoMetro']?.toString() ?? "",
    );
    final metragemController = TextEditingController(
      text: data['metragem']?.toString() ?? "",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nome),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: precoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Preço",
                hintText: "Ex: 5.90",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: metragemController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Metragem (m)",
                hintText: "Ex: 50",
              ),
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
              double? parse(String t) =>
                  double.tryParse(t.replaceAll(',', '.'));

              final preco = parse(precoController.text.trim());
              final metragem = parse(metragemController.text.trim());

              try {
                await doc.reference.update({
                  'precoMetro': preco,
                  'metragem': metragem,
                });
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Dados atualizados para "$nome".'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text("Erro ao salvar dados do item: $e"),
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

  Future<bool> _confirmDelete(BuildContext context, String nome) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Remover item"),
            content: Text('Deseja remover o item "$nome"?'),
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
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('unitType', isEqualTo: 'metro')
        .where('subcategory', isEqualTo: subcategoryKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _showAddItemDialog(context),
              icon: const Icon(Icons.add_circle_outline),
              tooltip: "Adicionar item em $title",
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
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
                "Nenhum item cadastrado ainda.",
                style: TextStyle(color: Colors.grey),
              );
            }

            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final da = (a.data() as Map<String, dynamic>? ?? {});
                final db = (b.data() as Map<String, dynamic>? ?? {});
                final na = (da['name'] ?? '') as String;
                final nb = (db['name'] ?? '') as String;
                return na.toLowerCase().compareTo(nb.toLowerCase());
              });

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final nome = (data['name'] ?? '') as String;
              if (searchTerm.isEmpty) return true;
              return nome.toLowerCase().contains(searchTerm);
            }).toList();

            return Column(
              children: [
                for (final doc in filteredDocs) ...[
                  Builder(
                    builder: (ctx) {
                      final data =
                          doc.data() as Map<String, dynamic>? ?? {};
                      final nome = data['name'] as String? ?? "(sem nome)";
                      final preco = _formatPreco(data['precoMetro']);
                      final metragem =
                          _formatMetragem(data['metragem']);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Dismissible(
                          key: ValueKey(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.red.withOpacity(0.8),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) =>
                              _confirmDelete(context, nome),
                          onDismissed: (direction) async {
                            try {
                              await doc.reference.delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Item "$nome" removido.'),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Erro ao remover item: $e"),
                                ),
                              );
                            }
                          },
                          child: _MetroItemRowCard(
                            nome: nome,
                            precoText: preco,
                            metragemText: metragem,
                            onTap: () => _showEditDialog(context, doc),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// =====================================================
//                       UNIDADE
// =====================================================

class _ItensUnidadeView extends StatefulWidget {
  const _ItensUnidadeView();

  @override
  State<_ItensUnidadeView> createState() => _ItensUnidadeViewState();
}

class _ItensUnidadeViewState extends State<_ItensUnidadeView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _formatPreco(dynamic v) {
    final d = _toDouble(v);
    if (d == null) return "-";
    return "R\$ ${d.toStringAsFixed(2)}";
  }

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

  Future<void> _showAddItemDialog(BuildContext context) async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Novo Item"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Nome do item",
              hintText: "Ex: Parafuso X",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                final nome = nameController.text.trim();

                if (nome.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('items').add({
                    'name': nome,
                    'unitType': 'unidade', // ✅ corrige tipo
                    'subcategory': null,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Item "$nome" adicionado com sucesso.'),
                      ),
                    );
                  }

                  Navigator.pop(ctx);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Erro ao salvar item: $e"),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                "Adicionar",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final nome = data['name'] as String? ?? "(sem nome)";

    final precoController = TextEditingController(
      text: data['precoUnidade']?.toString() ?? "",
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nome),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: precoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Preço / Und (R\$)",
                hintText: "Ex: 1.50",
                border: OutlineInputBorder(),
              ),
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
              double? parse(String t) =>
                  double.tryParse(t.replaceAll(',', '.'));

              final preco = parse(precoController.text.trim());

              try {
                await doc.reference.update({
                  'precoUnidade': preco,
                });
                // ignore: use_build_context_synchronously
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Preço atualizado para "$nome".',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Erro ao salvar dados do item: $e"),
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

  Future<bool> _confirmDelete(BuildContext context, String nome) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remover item"),
        content: Text('Deseja remover o item "$nome"?'),
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
    );

    return result ?? false; // 👈 GARANTE QUE SEMPRE VOLTA UM BOOL
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('items')
        .where('unitType', isEqualTo: 'unidade');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: "Buscar item (Unidade)",
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Row(
                children: [
                  const Text(
                    "Unidade",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showAddItemDialog(context),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: "Adicionar item em Unidade",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      "Erro ao carregar itens: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Text(
                      "Carregando itens...",
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Text(
                      "Nenhum item cadastrado ainda.",
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  final docs = snapshot.data!.docs.toList()
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

                  final filteredDocs = docs.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>? ?? {};
                    final nome = (data['name'] ?? '') as String;
                    if (_searchTerm.isEmpty) return true;
                    return nome.toLowerCase().contains(_searchTerm);
                  }).toList();

                  return Column(
                    children: [
                      for (final doc in filteredDocs) ...[
                        Builder(
                          builder: (ctx) {
                            final data =
                                doc.data() as Map<String, dynamic>? ?? {};
                            final nome =
                                data['name'] as String? ?? "(sem nome)";
                            final preco =
                                _formatPreco(data['precoUnidade']);

                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8.0),
                              child: Dismissible(
                                key: ValueKey(doc.id),
                                direction:
                                    DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  color:
                                      Colors.red.withOpacity(0.8),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (direction) =>
                                    _confirmDelete(context, nome),
                                onDismissed: (direction) async {
                                  try {
                                    await doc.reference.delete();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Item "$nome" removido.'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Erro ao remover item: $e"),
                                      ),
                                    );
                                  }
                                },
                                child: _UnidadeItemRowCard(
                                  nome: nome,
                                  precoText: preco,
                                  onTap: () =>
                                      _showEditDialog(context, doc),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}