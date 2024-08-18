import 'package:flutter/material.dart';
import 'package:expense_repository/expense_repository.dart';
import 'package:intl/intl.dart';

class ExpenseDetailPage extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailPage({Key? key, required this.expense}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      child: AlertDialog(
        title: Center(child: Text('Expense Details', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 24, fontWeight: FontWeight.w600),)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Category: ${expense.category.name}'),
            Text('Date: ${DateFormat('dd/MM/yyyy').format(expense.date)}'),
            Text('Amount: \$${expense.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            if (expense.photoUrl.isNotEmpty)
              Image.network(expense.photoUrl),
            if (expense.photoUrl.isEmpty)
              const Text('No photo available'),
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
            
            ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white),),
            ),
          ),
        ],
      ),
    );
  }
}
