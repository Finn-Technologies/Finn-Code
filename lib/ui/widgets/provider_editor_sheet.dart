import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/provider_config.dart';
import '../../viewmodels/app_view_model.dart';

Future<void> showProviderEditor(
  BuildContext context, {
  ProviderConfig? provider,
}) async {
  final viewModel = context.read<AppViewModel>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _ProviderEditorSheet(provider: provider, viewModel: viewModel),
  );
}

class _ProviderEditorSheet extends StatefulWidget {
  const _ProviderEditorSheet({required this.provider, required this.viewModel});

  final ProviderConfig? provider;
  final AppViewModel viewModel;

  @override
  State<_ProviderEditorSheet> createState() => _ProviderEditorSheetState();
}

class _ProviderEditorSheetState extends State<_ProviderEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _descriptionController;
  late ProviderProtocol _protocol;
  late bool _isFreeTier;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    _nameController = TextEditingController(
      text: provider?.name ?? 'My provider',
    );
    _baseUrlController = TextEditingController(text: provider?.baseUrl ?? '');
    _modelController = TextEditingController(text: provider?.model ?? '');
    _apiKeyController = TextEditingController(text: provider?.apiKey ?? '');
    _descriptionController = TextEditingController(
      text: provider?.description ?? '',
    );
    _protocol = provider?.protocol ?? ProviderProtocol.openAICompatible;
    _isFreeTier = provider?.isFreeTier ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    final existing = widget.provider;
    final name = _nameController.text.trim();
    final id =
        existing?.id ??
        '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
    final baseUrl = _baseUrlController.text.trim();
    final provider = ProviderConfig(
      id: id,
      name: name,
      protocol: _protocol,
      baseUrl: _protocol == ProviderProtocol.demo ? '' : baseUrl,
      model: _modelController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      description: _descriptionController.text.trim(),
      isFreeTier: _isFreeTier,
      allowsAnonymousAccess: existing?.allowsAnonymousAccess ?? false,
      isBuiltIn: existing?.isBuiltIn ?? false,
      isLocal:
          existing?.isLocal ??
          baseUrl.contains('10.0.2.2') ||
              baseUrl.contains('localhost') ||
              baseUrl.contains('127.0.0.1'),
    );
    try {
      if (existing == null) {
        await widget.viewModel.addProvider(provider);
      } else {
        await widget.viewModel.updateProvider(provider);
      }
      if (mounted) await Navigator.of(context).maybePop();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save provider: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        widget.provider == null
                            ? 'Add provider'
                            : 'Edit provider',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use a native adapter or any OpenAI-compatible endpoint.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ProviderProtocol>(
                        initialValue: _protocol,
                        decoration: const InputDecoration(
                          labelText: 'Protocol',
                        ),
                        items: ProviderProtocol.values
                            .map(
                              (protocol) => DropdownMenuItem<ProviderProtocol>(
                                value: protocol,
                                child: Text(protocol.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _protocol = value);
                        },
                      ),
                      if (_protocol != ProviderProtocol.demo) ...<Widget>[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _baseUrlController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Base URL',
                            hintText: switch (_protocol) {
                              ProviderProtocol.onDevice =>
                                'https://opencode.ai/zen/v1',
                              ProviderProtocol.openAICompatible =>
                                'https://api.example.com/v1',
                              ProviderProtocol.anthropic =>
                                'https://api.anthropic.com/v1',
                              ProviderProtocol.gemini =>
                                'https://generativelanguage.googleapis.com/v1beta',
                              ProviderProtocol.codex => 'ws://10.0.2.2:4500',
                              ProviderProtocol.demo => '',
                            },
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _modelController,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            hintText:
                                'Model ID or leave blank for gateway discovery',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _apiKeyController,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: _protocol == ProviderProtocol.codex
                                ? 'Bearer token (optional)'
                                : 'API key',
                            helperText: _protocol == ProviderProtocol.codex
                                ? 'Stored in Android encrypted storage when provided.'
                                : 'Never written to logs. Stored in secure storage.',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Free or local tier'),
                        subtitle: const Text(
                          'Mark this provider for quick testing.',
                        ),
                        value: _isFreeTier,
                        onChanged: (value) =>
                            setState(() => _isFreeTier = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('save-provider-button'),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_isSaving ? 'Saving…' : 'Save provider'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }
}
