import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResumeService {
  Future<void> editValorTotalDialog(
    BuildContext context, {
    required DocumentSnapshot itemDoc,
    required String itemName,
  }) async {
    final data = itemDoc.data() as Map<String, dynamic>? ?? {};

    final nomeAtual = (data['itemName'] ?? data['name'] ?? itemName) as String;
    final precoAtual = data['precoUnd'];
    final qtdAtual = data['quantidadeUnd'];

    final String medidaAtual = (data['medidaValorTotal'] as String?) ?? "Und";

    final nomeController = TextEditingController(text: nomeAtual);
    final precoController =
        TextEditingController(text: precoAtual == null ? '' : precoAtual.toString());
    final qtdController =
        TextEditingController(text: qtdAtual == null ? '' : qtdAtual.toString());

    double? parse(String t) => double.tryParse(t.replaceAll(',', '.'));

    const medidaOptions = ["Und", "m³", "m²", "m", "L"];

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        String medidaSelecionada = medidaAtual;

        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return AlertDialog(
              title: Text('Valor Total - $nomeAtual'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: "Nome",
                        hintText: "Ex: Total marcenaria",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: medidaOptions.contains(medidaSelecionada)
                          ? medidaSelecionada
                          : medidaOptions.first,
                      items: medidaOptions
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
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
                  onPressed: () => Navigator.pop(dialogCtx),
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
                        'medidaValorTotal': medidaSelecionada,
                      });

                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Valor total atualizado para "${novoNome.isEmpty ? nomeAtual : novoNome}".',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erro ao salvar Valor Total: $e")),
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

    // optional cleanup
    nomeController.dispose();
    precoController.dispose();
    qtdController.dispose();
  }
}