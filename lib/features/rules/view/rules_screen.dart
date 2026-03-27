import 'package:flutter/material.dart';
import 'package:format_docs/features/rules/models/rules.dart';
import 'package:format_docs/features/rules/view_model/rules_view_model.dart';
import 'package:format_docs/initializer.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  static const routeName = '/rules';

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  late final RulesViewModel _rulesViewModel;

  @override
  void initState() {
    super.initState();
    _rulesViewModel = getIt<RulesViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rulesViewModel.fetchRules();
    });
  }

  Future<void> _refresh() async {
    await _rulesViewModel.fetchRules();
  }

  Future<void> _openCreateRuleDialog() async {
    final rule = await showDialog<Rule>(
      context: context,
      builder: (_) => const _CreateRuleDialog(),
    );

    if (rule == null || !mounted) return;

    await _rulesViewModel.createRule(rule);
    if (!mounted) return;

    final message = _rulesViewModel.errorMessage ?? 'Regra criada com sucesso.';
    final color =
        _rulesViewModel.errorMessage == null
            ? null
            : Theme.of(context).colorScheme.error;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _deleteRule(Rule rule) async {
    final id = rule.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Excluir regra'),
            content: Text(
              'Deseja realmente excluir a regra "${rule.triggerWord}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    await _rulesViewModel.deleteRule(id);
    if (!mounted) return;

    final message =
        _rulesViewModel.errorMessage ?? 'Regra excluída com sucesso.';
    final color =
        _rulesViewModel.errorMessage == null
            ? null
            : Theme.of(context).colorScheme.error;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar regras'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _rulesViewModel.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _rulesViewModel.isLoading ? null : _openCreateRuleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nova regra'),
      ),
      body: ListenableBuilder(
        listenable: _rulesViewModel,
        builder: (context, _) {
          if (_rulesViewModel.isLoading && _rulesViewModel.rules.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = _rulesViewModel.errorMessage;
          final rules = _rulesViewModel.rules;

          if (rules.isEmpty) {
            return _EmptyState(
              message:
                  error == null
                      ? 'Nenhuma regra cadastrada ainda.'
                      : _normalizeError(error),
              actionLabel: error == null ? 'Criar regra' : 'Tentar novamente',
              onAction:
                  error == null
                      ? _openCreateRuleDialog
                      : _rulesViewModel.fetchRules,
            );
          }

          return Column(
            children: [
              if (error != null)
                _ErrorBanner(
                  message: _normalizeError(error),
                  onRetry: _refresh,
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      return _RuleCard(
                        rule: rule,
                        onDelete:
                            _rulesViewModel.isLoading
                                ? null
                                : () => _deleteRule(rule),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemCount: rules.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _normalizeError(String message) {
    return message.startsWith('Exception: ')
        ? message.replaceFirst('Exception: ', '')
        : message;
  }
}

class _RuleCard extends StatelessWidget {
  final Rule rule;
  final VoidCallback? onDelete;

  const _RuleCard({required this.rule, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final chips = _buildInfoChips();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rule.triggerWord,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Excluir regra',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Text(
              _ruleTypeLabel(rule.ruleType),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips.map((chip) => Chip(label: Text(chip))).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _buildInfoChips() {
    final result = <String>[];

    if (rule.replacement != null && rule.replacement!.trim().isNotEmpty) {
      result.add('Substituir por: ${rule.replacement}');
    }
    if (rule.bold) result.add('Negrito');
    if (rule.italic) result.add('Itálico');
    if (rule.underline) result.add('Sublinhado');
    if (rule.color != null && rule.color!.trim().isNotEmpty) {
      result.add('Cor: ${rule.color}');
    }

    return result;
  }

  String _ruleTypeLabel(RuleType type) {
    switch (type) {
      case RuleType.formattingTrigger:
        return 'Gatilho de formatação';
      case RuleType.wordSubstitution:
        return 'Substituição de termo';
      case RuleType.paragraphSymbol:
        return 'Validação de símbolo §';
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rule_folder_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _CreateRuleDialog extends StatefulWidget {
  const _CreateRuleDialog();

  @override
  State<_CreateRuleDialog> createState() => _CreateRuleDialogState();
}

class _CreateRuleDialogState extends State<_CreateRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _triggerController = TextEditingController();
  final _replacementController = TextEditingController();
  final _colorController = TextEditingController();

  RuleType _ruleType = RuleType.formattingTrigger;
  bool _bold = false;
  bool _italic = true;
  bool _underline = false;

  @override
  void dispose() {
    _triggerController.dispose();
    _replacementController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _onRuleTypeChanged(RuleType? value) {
    if (value == null) return;

    setState(() {
      _ruleType = value;

      if (_ruleType != RuleType.wordSubstitution) {
        _replacementController.clear();
      }

      if (_ruleType == RuleType.paragraphSymbol &&
          _triggerController.text.trim().isEmpty) {
        _triggerController.text = '§';
      }

      if (_ruleType != RuleType.formattingTrigger) {
        _bold = false;
        _italic = false;
        _underline = false;
        _colorController.clear();
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final triggerWord = _triggerController.text.trim();
    final replacement = _replacementController.text.trim();
    final color = _colorController.text.trim();

    final rule = Rule(
      triggerWord: triggerWord,
      ruleType: _ruleType,
      replacement: replacement.isEmpty ? null : replacement,
      bold: _ruleType == RuleType.formattingTrigger ? _bold : false,
      italic: _ruleType == RuleType.formattingTrigger ? _italic : false,
      underline: _ruleType == RuleType.formattingTrigger ? _underline : false,
      color:
          _ruleType == RuleType.formattingTrigger && color.isNotEmpty
              ? color
              : null,
    );

    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    final showReplacement = _ruleType == RuleType.wordSubstitution;
    final showFormatting = _ruleType == RuleType.formattingTrigger;

    return AlertDialog(
      title: const Text('Nova regra'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<RuleType>(
                  value: _ruleType,
                  items:
                      RuleType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(_ruleTypeLabel(type)),
                            ),
                          )
                          .toList(),
                  onChanged: _onRuleTypeChanged,
                  decoration: const InputDecoration(labelText: 'Tipo de regra'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _triggerController,
                  decoration: InputDecoration(
                    labelText: _triggerLabel(_ruleType),
                    hintText:
                        _ruleType == RuleType.paragraphSymbol
                            ? 'Ex.: §'
                            : 'Ex.: Código Penal',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o gatilho da regra.';
                    }
                    return null;
                  },
                ),
                if (showReplacement) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _replacementController,
                    decoration: const InputDecoration(
                      labelText: 'Substituir por',
                      hintText: 'Ex.: CP',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o texto de substituição.';
                      }
                      return null;
                    },
                  ),
                ],
                if (showFormatting) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Negrito'),
                    value: _bold,
                    onChanged: (value) => setState(() => _bold = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Itálico'),
                    value: _italic,
                    onChanged: (value) => setState(() => _italic = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sublinhado'),
                    value: _underline,
                    onChanged: (value) => setState(() => _underline = value),
                  ),
                  TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Cor (hex, opcional)',
                      hintText: '#1F2937',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;

                      final colorRegex = RegExp(
                        r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
                      );
                      if (!colorRegex.hasMatch(text)) {
                        return 'Use formato #RRGGBB ou #RRGGBBAA.';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salvar')),
      ],
    );
  }

  String _ruleTypeLabel(RuleType type) {
    switch (type) {
      case RuleType.formattingTrigger:
        return 'Gatilho de formatação';
      case RuleType.wordSubstitution:
        return 'Substituição de termo';
      case RuleType.paragraphSymbol:
        return 'Validação de símbolo §';
    }
  }

  String _triggerLabel(RuleType type) {
    switch (type) {
      case RuleType.formattingTrigger:
        return 'Palavra gatilho';
      case RuleType.wordSubstitution:
        return 'Texto a substituir';
      case RuleType.paragraphSymbol:
        return 'Símbolo gatilho';
    }
  }
}
