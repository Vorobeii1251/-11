import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ============================================================================
// ТОЧКА ВХОДА
// ============================================================================

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MoneyVore',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const MoneyVoreHomePage(),
    );
  }
}

// ============================================================================
// МОДЕЛЬ КАТЕГОРИИ
// ============================================================================

class Category {
  final String name;
  final String icon;
  final Color color;

  const Category({
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<Category> defaultCategories = [
    Category(name: 'Еда', icon: '🍔', color: Colors.orange),
    Category(name: 'Транспорт', icon: '🚗', color: Colors.blue),
    Category(name: 'Кафе', icon: '☕', color: Colors.brown),
    Category(name: 'Развлечения', icon: '🎬', color: Colors.purple),
    Category(name: 'Продукты', icon: '🛒', color: Colors.green),
    Category(name: 'Другое', icon: '📦', color: Colors.grey),
  ];

  static Category getById(int id) {
    return defaultCategories[id % defaultCategories.length];
  }
}

// ============================================================================
// МОДЕЛЬ РАСХОДА
// ============================================================================

class ExpenseItem {
  final int id;
  final String name;
  final double amount;
  final DateTime date;
  final int categoryId;

  ExpenseItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.categoryId,
  });

  String get formattedDate => DateFormat('dd.MM.yyyy HH:mm').format(date);
  Category get category => Category.getById(categoryId);
}

// ============================================================================
// СЕРВИС ДЛЯ РАБОТЫ С ДАННЫМИ (В ПАМЯТИ)
// ============================================================================

class DataService {
  final List<ExpenseItem> _expenses = [];
  int _nextId = 1;
  double _salary = 0.0;

  List<ExpenseItem> get expenses => List.unmodifiable(_expenses);

  double get salary => _salary;
  double get currentBudget => _salary - getTotalExpenses();

  void setSalary(double amount) {
    _salary = amount;
  }

  void addExpense(ExpenseItem expense) {
    _expenses.add(ExpenseItem(
      id: _nextId++,
      name: expense.name,
      amount: expense.amount,
      date: expense.date,
      categoryId: expense.categoryId,
    ));
  }

  void updateExpense(ExpenseItem expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
    }
  }

  void deleteExpense(int id) {
    _expenses.removeWhere((e) => e.id == id);
  }

  double getTotalExpenses() {
    return _expenses.fold(0.0, (sum, e) => sum + e.amount);
  }
}

// ============================================================================
// ГЛАВНЫЙ ЭКРАН
// ============================================================================

class MoneyVoreHomePage extends StatefulWidget {
  const MoneyVoreHomePage({super.key});

  @override
  State<MoneyVoreHomePage> createState() => _MoneyVoreHomePageState();
}

class _MoneyVoreHomePageState extends State<MoneyVoreHomePage> {
  final DataService _dataService = DataService();

  List<ExpenseItem> _expenses = [];
  List<ExpenseItem> _filteredExpenses = [];
  double _salary = 0.0;
  double _currentBudget = 0.0;
  int? _daysCanLive;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _searchQuery = '';
  String _sortBy = 'date';
  bool _sortAscending = false;
  int? _selectedCategoryId;
  ExpenseItem? _editingExpense;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _expenses = _dataService.expenses;
      _salary = _dataService.salary;
      _currentBudget = _dataService.currentBudget;
      _applyFiltersAndSort();
      _calculateDaysCanLive();
    });
  }

  void _calculateDaysCanLive() {
    if (_currentBudget <= 0 || _expenses.isEmpty) {
      _daysCanLive = null;
      return;
    }

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekExpenses = _expenses.where((e) => e.date.isAfter(weekAgo)).toList();

    if (weekExpenses.isEmpty) {
      _daysCanLive = null;
      return;
    }

    final totalWeekSpend = weekExpenses.fold(0.0, (s, e) => s + e.amount);
    final dailyAverage = totalWeekSpend / 7;

    if (dailyAverage <= 0) {
      _daysCanLive = null;
      return;
    }

    _daysCanLive = (_currentBudget / dailyAverage).floor();
  }

  void _applyFiltersAndSort() {
    var filtered = List<ExpenseItem>.from(_expenses);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final double? amountQuery = double.tryParse(_searchQuery.replaceAll(',', '.'));

      filtered = filtered.where((e) {
        if (e.name.toLowerCase().contains(query)) return true;
        if (amountQuery != null && e.amount == amountQuery) return true;
        return false;
      }).toList();
    }

    if (_selectedCategoryId != null) {
      filtered = filtered.where((e) => e.categoryId == _selectedCategoryId).toList();
    }

    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'amount':
          comparison = a.amount.compareTo(b.amount);
          break;
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        default:
          comparison = a.date.compareTo(b.date);
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredExpenses = filtered;
    });
  }

  double get _totalAmount {
    return _filteredExpenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  void _showSalaryDialog() {
    _salaryController.text = _salary.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: Colors.green),
            SizedBox(width: 8),
            Text('Установить зарплату / бюджет'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _salaryController,
              decoration: const InputDecoration(
                labelText: 'Сумма бюджета',
                prefixIcon: Icon(Icons.currency_ruble),
                hintText: 'Например: 50000',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Введите сумму';
                if (double.tryParse(v) == null) return 'Введите число';
                if (double.parse(v) < 0) return 'Сумма не может быть отрицательной';
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Эта сумма — ваш ежемесячный бюджет.\nПриложение будет считать, сколько дней вы можете прожить на остаток.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () {
              final amount = double.tryParse(_salaryController.text);
              if (amount != null && amount > 0) {
                _dataService.setSalary(amount);
                _loadData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Бюджет установлен: ${amount.toStringAsFixed(0)} ₽'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showExpenseForm({ExpenseItem? expense}) {
    _editingExpense = expense;
    _nameController.text = expense?.name ?? '';
    _amountController.text = expense?.amount.toString() ?? '';
    _selectedCategoryId = expense?.categoryId ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(expense == null ? Icons.add_box : Icons.edit, color: Colors.teal),
                const SizedBox(width: 8),
                Text(expense == null ? 'Новый расход' : 'Редактировать'),
              ],
            ),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Введите название' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      prefixIcon: Icon(Icons.currency_ruble),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Введите сумму';
                      if (double.tryParse(v) == null) return 'Введите число';
                      if (double.parse(v) <= 0) return 'Сумма должна быть больше 0 ₽';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: Category.defaultCategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final cat = entry.value;
                      return DropdownMenuItem(
                        value: index,
                        child: Text('${cat.icon} ${cat.name}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              FilledButton.icon(
                onPressed: () => _saveExpense(expense),
                icon: Icon(expense == null ? Icons.save : Icons.update),
                label: Text(expense == null ? 'Сохранить' : 'Обновить'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveExpense(ExpenseItem? existingExpense) {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final amount = double.parse(_amountController.text);

      if (existingExpense != null) {
        _dataService.updateExpense(ExpenseItem(
          id: existingExpense.id,
          name: name,
          amount: amount,
          date: existingExpense.date,
          categoryId: _selectedCategoryId!,
        ));
      } else {
        _dataService.addExpense(ExpenseItem(
          id: 0,
          name: name,
          amount: amount,
          date: DateTime.now(),
          categoryId: _selectedCategoryId!,
        ));
      }

      _loadData();
      Navigator.pop(context);
    }
  }

  void _deleteExpense(ExpenseItem expense) {
    _dataService.deleteExpense(expense.id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalAmount;
    final totalFormatted = total.toStringAsFixed(2);
    final totalInteger = total.toInt();
    final totalFraction = total - totalInteger;

    final budgetInteger = _currentBudget.toInt();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, color: Colors.tealAccent),
            const SizedBox(width: 8),
            const Text('MoneyVore'),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('🐷 копилка', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showSalaryDialog,
            icon: const Icon(Icons.monetization_on),
            tooltip: 'Бюджет',
          ),
        ],
      ),
      body: Column(
        children: [
          // Блок с бюджетом
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade800, Colors.teal.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '💰 БЮДЖЕТ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                    Row(
                      children: [
                        Text(
                          _salary > 0 ? 'от 1₽' : 'бюджет Не установлен',
                          style: TextStyle(
                            fontSize: 14,
                            color: _salary > 0 ? Colors.white70 : Colors.red.shade300,
                          ),
                        ),
                        IconButton(
                          onPressed: _showSalaryDialog,
                          icon: Icon(Icons.edit, size: 18, color: Colors.white70),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Остаток',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        Text(
                          '${budgetInteger.toString()} ₽',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    if (_daysCanLive != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'братан тебе осталось прожить',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          Row(
                            children: [
                              Text(
                                '${_daysCanLive}',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const Text(
                                ' дней',
                                style: TextStyle(fontSize: 16, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
                if (_daysCanLive == null && _expenses.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Добавьте больше расходов для расчёта',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),

          // Панель поиска
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '🔍 Поиск по названию или сумме',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFiltersAndSort();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: _selectedCategoryId,
                  hint: const Text('📂 Все'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('📂 Все категории')),
                    ...Category.defaultCategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final cat = entry.value;
                      return DropdownMenuItem(
                        value: index,
                        child: Text('${cat.icon} ${cat.name}'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                      _applyFiltersAndSort();
                    });
                  },
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Сортировка',
                  onSelected: (value) {
                    setState(() {
                      if (_sortBy == value) {
                        _sortAscending = !_sortAscending;
                      } else {
                        _sortBy = value;
                        _sortAscending = false;
                      }
                      _applyFiltersAndSort();
                    });
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'date', child: Text('📅 По дате')),
                    PopupMenuItem(value: 'amount', child: Text('💰 По сумме')),
                    PopupMenuItem(value: 'name', child: Text('🔤 По названию')),
                  ],
                ),
              ],
            ),
          ),

          // Сумма по категориям
          if (_expenses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CategorySummaryWidget(expenses: _filteredExpenses),
            ),

          const SizedBox(height: 8),

          // Список расходов
          Expanded(
            child: _filteredExpenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _expenses.isEmpty ? 'Нет записей' : 'Ничего не найдено',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        if (_expenses.isEmpty)
                          const Text(
                            'Нажмите + чтобы добавить расход',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _filteredExpenses.length,
                    separatorBuilder: (_, __) => const Divider(height: 0, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final expense = _filteredExpenses[index];
                      return Dismissible(
                        key: Key(expense.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_forever, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Удалить запись?'),
                              content: Text('Вы уверены, что хотите удалить "${expense.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Отмена'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Удалить'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) => _deleteExpense(expense),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: expense.category.color.withValues(alpha: 0.2),
                            child: Text(expense.category.icon, style: const TextStyle(fontSize: 20)),
                          ),
                          title: Text(
                            expense.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text('${expense.formattedDate} • ${expense.category.name}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${expense.amount.toStringAsFixed(2)} ₽',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showExpenseForm(expense: expense),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        ),
                      );
                    },
                  ),
          ),

          // Нижняя панель с итогом
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.attach_money, size: 20, color: Colors.tealAccent),
                    SizedBox(width: 8),
                    Text('ИТОГО', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      totalInteger.toString(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    if (totalFraction > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 4),
                        child: Text(
                          totalFormatted.split('.')[1],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 4),
                      child: Text('₽', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showExpenseForm,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'Добавить расход',
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
    );
  }
}

// ============================================================================
// ВИДЖЕТ СУММЫ ПО КАТЕГОРИЯМ
// ============================================================================

class CategorySummaryWidget extends StatelessWidget {
  final List<ExpenseItem> expenses;

  const CategorySummaryWidget({super.key, required this.expenses});

  Map<String, double> _getCategorySums() {
    final Map<String, double> sums = {};
    for (final expense in expenses) {
      final categoryName = expense.category.name;
      sums[categoryName] = (sums[categoryName] ?? 0) + expense.amount;
    }
    return sums;
  }

  @override
  Widget build(BuildContext context) {
    final categorySums = _getCategorySums();

    if (categorySums.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Нет расходов для отображения',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart, size: 16, color: Colors.tealAccent),
              SizedBox(width: 8),
              Text(
                'Сумма по категориям',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.tealAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Category.defaultCategories.map((category) {
              final sum = categorySums[category.name] ?? 0;
              if (sum == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: category.color.withValues(alpha: 0.5), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${sum.toStringAsFixed(0)} ₽',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: category.color),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}