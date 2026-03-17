import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/translations.g.dart';

import '../models/online_provider_config.dart';
import '../viewmodels/settings_view_model.dart';

/// Settings page for managing online source providers
class OnlineProvidersSettingsPage extends StatefulWidget {
  const OnlineProvidersSettingsPage({super.key});

  @override
  State<OnlineProvidersSettingsPage> createState() =>
      _OnlineProvidersSettingsPageState();
}

class _OnlineProvidersSettingsPageState
    extends State<OnlineProvidersSettingsPage> {
  List<OnlineProviderConfig> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    if (!mounted) return;

    final viewModel = context.read<SettingsViewModel>();
    final providers = await viewModel.getOnlineProviders();

    if (mounted) {
      setState(() {
        _providers = providers;
        _isLoading = false;
      });
    }
  }

  Future<void> _addOrEditProvider([OnlineProviderConfig? existing]) async {
    final result = await showDialog<OnlineProviderConfig>(
      context: context,
      builder: (context) => _ProviderEditDialog(provider: existing),
    );

    if (result != null && mounted) {
      final viewModel = context.read<SettingsViewModel>();
      await viewModel.saveOnlineProvider(result);
      await _loadProviders();
    }
  }

  Future<void> _deleteProvider(String providerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.common.delete),
        content: const Text(
          'Are you sure you want to delete this provider configuration?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t.common.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final viewModel = context.read<SettingsViewModel>();
      await viewModel.removeOnlineProvider(providerId);
      await _loadProviders();
    }
  }

  Future<void> _toggleProvider(String providerId, bool enabled) async {
    if (!mounted) return;
    final viewModel = context.read<SettingsViewModel>();
    await viewModel.setOnlineProviderEnabled(providerId, enabled);
    if (mounted) {
      await _loadProviders();
    }
  }

  Future<void> _testConnection(OnlineProviderConfig config) async {
    if (!mounted) return;

    final viewModel = context.read<SettingsViewModel>();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.settings.testingConnection)));
    }

    final success = await viewModel.testOnlineProviderConnection(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? context.t.settings.connectionSuccess
                : context.t.settings.connectionFailed,
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.onlineProviders.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
          ? _buildEmptyState()
          : _buildProviderList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addOrEditProvider,
        tooltip: context.t.onlineProviders.addProvider,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            context.t.onlineProviders.noProviders,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            context.t.onlineProviders.noProvidersHint,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addOrEditProvider,
            icon: const Icon(Icons.add),
            label: Text(context.t.onlineProviders.addProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _providers.length,
      itemBuilder: (context, index) {
        final provider = _providers[index];
        return Card(
          child: ListTile(
            leading: Icon(
              provider.enabled ? Icons.cloud : Icons.cloud_off,
              color: provider.enabled ? Colors.green : Colors.grey,
            ),
            title: Text(provider.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${context.t.common.id}: ${provider.providerId}'),
                Text('${context.t.common.url}: ${provider.baseUrl}'),
                if (provider.apiKey != null) Text('${context.t.common.apiKey}: •••••••'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: provider.enabled,
                  onChanged: (value) =>
                      _toggleProvider(provider.providerId, value),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _addOrEditProvider(provider);
                      case 'test':
                        _testConnection(provider);
                      case 'delete':
                        _deleteProvider(provider.providerId);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(context.t.common.edit)),
                    PopupMenuItem(
                      value: 'test',
                      child: Text(context.t.common.testConnection),
                    ),
                    PopupMenuItem(value: 'delete', child: Text(context.t.common.delete)),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

/// Dialog for adding/editing provider configuration
class _ProviderEditDialog extends StatefulWidget {
  const _ProviderEditDialog({this.provider});

  final OnlineProviderConfig? provider;

  @override
  State<_ProviderEditDialog> createState() => _ProviderEditDialogState();
}

class _ProviderEditDialogState extends State<_ProviderEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _providerIdController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _timeoutController;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    _providerIdController = TextEditingController(
      text: provider?.providerId ?? '',
    );
    _displayNameController = TextEditingController(
      text: provider?.displayName ?? '',
    );
    _baseUrlController = TextEditingController(text: provider?.baseUrl ?? '');
    _apiKeyController = TextEditingController(text: provider?.apiKey ?? '');
    _timeoutController = TextEditingController(
      text: (provider?.timeout ?? 10).toString(),
    );
    _enabled = provider?.enabled ?? true;
  }

  @override
  void dispose() {
    _providerIdController.dispose();
    _displayNameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final config = OnlineProviderConfig(
      providerId: _providerIdController.text.trim(),
      displayName: _displayNameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      enabled: _enabled,
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
      timeout: int.tryParse(_timeoutController.text) ?? 10,
    );

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.provider != null;

    return AlertDialog(
      title: Text(isEditing ? context.t.onlineProviders.editProvider : context.t.onlineProviders.addProvider),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _providerIdController,
                decoration: InputDecoration(
                  labelText: context.t.onlineProviders.providerIdLabel,
                  hintText: context.t.onlineProviders.providerIdHint,
                ),
                enabled: !isEditing,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Provider ID is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: context.t.onlineProviders.displayNameLabel,
                  hintText: context.t.onlineProviders.displayNameHint,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _baseUrlController,
                decoration: InputDecoration(
                  labelText: context.t.onlineProviders.baseUrlLabel,
                  hintText: context.t.onlineProviders.baseUrlHint,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Base URL is required';
                  }
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return 'URL must start with http:// or https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: context.t.onlineProviders.apiKeyOptional,
                  hintText: context.t.onlineProviders.apiKeyHint,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeoutController,
                decoration: InputDecoration(
                  labelText: context.t.onlineProviders.timeoutLabel,
                  hintText: context.t.onlineProviders.timeoutDefault,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final timeout = int.tryParse(value);
                    if (timeout == null || timeout < 1) {
                      return context.t.onlineProviders.timeoutError;
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: Text(context.t.common.enabled),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t.common.cancel),
        ),
        ElevatedButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
}
