import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import '../../../core/models/models.dart' as models;
import '../../../core/services/budget_service.dart';
import '../../../core/services/participant_service.dart';
import '../../../core/context.dart';

/// Manages account viewing, editing, and deletion in settings
/// Regular users see only accounts they're responsible for
/// Managers see all accounts
class AccountManagementViewModel extends ChangeNotifier {
  final BudgetService _budgetService;
  final ParticipantService _participantService;
  final AppContext _appContext;
  final Logger _logger = Logger("AccountManagementViewModel");

  AccountManagementViewModel(
    this._budgetService,
    this._participantService,
    this._appContext,
  );

  // ========== State Management ==========

  List<models.Account> _accounts = [];
  List<models.Account> get accounts => _accounts;

  List<models.Template> _accessibleTemplates = [];
  List<models.Template> get accessibleTemplates => _accessibleTemplates;

  List<models.Category> _categories = [];
  List<models.Category> get categories => _categories;

  int? _selectedTemplateId;
  int? get selectedTemplateId => _selectedTemplateId;

  int? _selectedCategoryId;
  int? get selectedCategoryId => _selectedCategoryId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // ========== Current User Info ==========

  models.Participant? get currentUser => _appContext.currentParticipant;
  bool get isManager => currentUser?.role == models.Role.manager;

  // ========== Form State ==========

  int? _editingAccountId;
  int? get editingAccountId => _editingAccountId;
  bool get isEditMode => _editingAccountId != null;

  final Map<String, dynamic> _formData = {
    'accountName': '',
    'categoryId': null,
    'colorHex': '',
    'budgetAmount': 0.0,
    'responsibleParticipantId': null,
  };

  dynamic getFormValue(String field) => _formData[field];

  // ========== Initialization ==========

  /// Load templates and accounts based on user access
  Future<void> initialize() async {
    await loadAccessibleTemplates();
    if (_accessibleTemplates.isNotEmpty) {
      await selectTemplate(_accessibleTemplates.first.templateId);
    }
  }

  /// Load all templates the user has access to
  Future<void> loadAccessibleTemplates() async {
    _setLoading(true);
    try {
      final allTemplates =
          await _budgetService.templateService.getAllTemplates();

      if (isManager) {
        // Manager sees all templates
        _accessibleTemplates = allTemplates;
      } else if (currentUser != null) {
        // Regular users see only templates they're part of
        _accessibleTemplates = [];
        for (final template in allTemplates) {
          final participants =
              await _participantService.getTemplateParticipants(
            template.templateId,
          );
          if (participants
              .any((p) => p.participantId == currentUser!.participantId)) {
            _accessibleTemplates.add(template);
          }
        }
      } else {
        _accessibleTemplates = [];
      }

      _clearError();
      _logger
          .info('Loaded ${_accessibleTemplates.length} accessible templates');
    } catch (e) {
      _logger.severe('Failed to load accessible templates', e);
      _setError('Failed to load templates: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Select a template and load its categories and accounts
  Future<void> selectTemplate(int templateId) async {
    _selectedTemplateId = templateId;
    _selectedCategoryId = null; // Reset category selection
    await loadCategoriesForTemplate(templateId);
    await loadAccountsForTemplate(templateId);
  }

  /// Load categories for a specific template
  Future<void> loadCategoriesForTemplate(int templateId) async {
    try {
      _categories =
          await _budgetService.categoryService.getCategoriesForTemplate(
        templateId,
      );
      _logger.info(
          'Loaded ${_categories.length} categories for template $templateId');
      notifyListeners();
    } catch (e) {
      _logger.severe('Failed to load categories', e);
      _categories = [];
    }
  }

  /// Select a category filter (null shows all)
  Future<void> selectCategory(int? categoryId) async {
    _selectedCategoryId = categoryId;
    if (_selectedTemplateId != null) {
      await loadAccountsForTemplate(_selectedTemplateId!);
    }
  }

  /// Load accounts for the selected template (and optionally category)
  Future<void> loadAccountsForTemplate(int templateId) async {
    _setLoading(true);
    try {
      List<models.Account> allAccounts;

      if (_selectedCategoryId != null) {
        // Load accounts for specific category
        allAccounts =
            await _budgetService.accountService.getAccountsForCategory(
          templateId,
          _selectedCategoryId!,
        );
      } else {
        // Load all accounts for template
        allAccounts =
            await _budgetService.accountService.getAllAccountsForTemplate(
          templateId,
        );
      }

      // Filter based on user role
      if (isManager) {
        // Manager sees all accounts
        _accounts = allAccounts;
      } else if (currentUser != null) {
        // Regular users see only accounts they're responsible for
        _accounts = allAccounts.where((account) {
          return account.responsibleParticipantId == currentUser!.participantId;
        }).toList();
      } else {
        _accounts = [];
      }

      _clearError();
      _logger
          .info('Loaded ${_accounts.length} accounts for template $templateId');
    } catch (e) {
      _logger.severe('Failed to load accounts', e);
      _setError('Failed to load accounts: $e');
      _accounts = [];
    } finally {
      _setLoading(false);
    }
  }

  // ========== Form Management ==========

  void updateFormField(String field, dynamic value) {
    _formData[field] = value;
    notifyListeners();
  }

  void _clearForm() {
    _formData.clear();
    _formData.addAll({
      'accountName': '',
      'categoryId': null,
      'colorHex': '',
      'budgetAmount': 0.0,
      'responsibleParticipantId': null,
    });
    _editingAccountId = null;
  }

  // ========== Validation ==========

  String? validateForm() {
    final accountName = (_formData['accountName'] as String?)?.trim() ?? '';
    final categoryId = _formData['categoryId'] as int?;
    final colorHex = (_formData['colorHex'] as String?)?.trim() ?? '';
    final budgetAmount = _formData['budgetAmount'] as double?;

    if (accountName.isEmpty) {
      return 'Account name is required';
    }

    if (categoryId == null) {
      return 'Category is required';
    }

    if (colorHex.isEmpty) {
      return 'Color is required';
    }

    // Validate hex color format
    final hexRegex = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$');
    if (!hexRegex.hasMatch(colorHex)) {
      return 'Invalid color format (use #RRGGBB or #AARRGGBB)';
    }

    if (budgetAmount == null || budgetAmount < 0) {
      return 'Budget amount must be a positive number';
    }

    return null;
  }

  // ========== Edit Account ==========

  /// Start editing an account
  void startEditing(models.Account account) {
    // Check permissions: only manager or responsible participant can edit
    final canEdit = isManager ||
        account.responsibleParticipantId == currentUser?.participantId;

    if (!canEdit) {
      _setError('You can only edit accounts you\'re responsible for');
      return;
    }

    _editingAccountId = account.accountId;
    _formData['accountName'] = account.accountName;
    _formData['categoryId'] = account.categoryId;
    _formData['colorHex'] = account.colorHex;
    _formData['budgetAmount'] = account.budgetAmount;
    _formData['responsibleParticipantId'] = account.responsibleParticipantId;
    _clearError();
    notifyListeners();
  }

  /// Update an existing account
  /// Returns true if successful
  Future<bool> updateAccount() async {
    if (_editingAccountId == null) return false;

    final validationError = validateForm();
    if (validationError != null) {
      _setError(validationError);
      return false;
    }

    _setLoading(true);
    try {
      final existingAccount = _accounts.firstWhere(
        (a) => a.accountId == _editingAccountId,
      );

      final account = models.Account(
        accountId: _editingAccountId!,
        categoryId: _formData['categoryId'] as int,
        templateId: existingAccount.templateId,
        accountName: (_formData['accountName'] as String).trim(),
        colorHex: (_formData['colorHex'] as String).trim(),
        budgetAmount: _formData['budgetAmount'] as double,
        expenditureTotal: existingAccount.expenditureTotal,
        responsibleParticipantId: _formData['responsibleParticipantId'] as int?,
        dateCreated: existingAccount.dateCreated,
      );

      final success =
          await _budgetService.accountService.modifyAccount(account);

      if (success) {
        _logger.info('Successfully updated account: $_editingAccountId');

        if (_selectedTemplateId != null) {
          await loadAccountsForTemplate(_selectedTemplateId!);
        }

        _clearForm();
        _clearError();
        return true;
      } else {
        _setError('Failed to update account');
        return false;
      }
    } catch (e) {
      _logger.severe('Error updating account', e);
      _setError('Error updating account: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel editing and clear form
  void cancelEditing() {
    _editingAccountId = null;
    _clearForm();
    _clearError();
    notifyListeners();
  }

  // ========== Delete Account ==========

  /// Delete an account
  /// Only manager or responsible participant can delete
  /// Returns true if successful
  Future<bool> deleteAccount(models.Account account) async {
    // Check permissions
    final canDelete = isManager ||
        account.responsibleParticipantId == currentUser?.participantId;

    if (!canDelete) {
      _setError('You can only delete accounts you\'re responsible for');
      return false;
    }

    _setLoading(true);
    try {
      final success = await _budgetService.accountService.deleteAccount(
        account.accountId,
      );

      if (success) {
        _logger.info('Successfully deleted account: ${account.accountId}');

        // If we were editing this account, clear the edit state
        if (_editingAccountId == account.accountId) {
          _clearForm();
        }

        if (_selectedTemplateId != null) {
          await loadAccountsForTemplate(_selectedTemplateId!);
        }

        _clearError();
        return true;
      } else {
        _setError('Failed to delete account');
        return false;
      }
    } catch (e) {
      _logger.severe('Error deleting account', e);
      _setError('Error deleting account: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ========== Helper Methods ==========

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get template name by ID
  String? getTemplateName(int templateId) {
    try {
      return _accessibleTemplates
          .firstWhere((t) => t.templateId == templateId)
          .templateName;
    } catch (e) {
      return null;
    }
  }

  /// Get category name by ID
  String? getCategoryName(int categoryId) {
    try {
      return _categories
          .firstWhere((c) => c.categoryId == categoryId)
          .categoryName;
    } catch (e) {
      return null;
    }
  }

  /// Get responsible participant name
  Future<String?> getResponsibleParticipantName(int? participantId) async {
    if (participantId == null) return 'Unassigned';

    try {
      final participant =
          await _participantService.getParticipant(participantId);
      if (participant != null) {
        return participant.nickname ?? participant.firstName;
      }
      return 'Unknown';
    } catch (e) {
      _logger.severe('Error getting participant name', e);
      return 'Unknown';
    }
  }

  /// Get transaction count for an account
  Future<int> getTransactionCount(int accountId) async {
    try {
      final transactions = await _budgetService.transactionService
          .getTransactionsForAccounts([accountId]);
      return transactions.length;
    } catch (e) {
      _logger.severe('Error getting transaction count', e);
      return 0;
    }
  }
}
