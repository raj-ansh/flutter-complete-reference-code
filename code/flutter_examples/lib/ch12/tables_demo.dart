import 'package:flutter/material.dart';

class Plant {
  const Plant(this.name, this.heightCm, this.sun);
  final String name;
  final int heightCm;
  final bool sun;
}

const plants = [
  Plant('Basil', 40, true),
  Plant('Fern', 60, false),
  Plant('Tomato', 150, true),
  Plant('Hosta', 55, false),
];

// #docregion table
/// Table: a simple grid where columns share widths.
class TableDemo extends StatelessWidget {
  const TableDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black26),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FixedColumnWidth(64),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
          children: [
            Padding(padding: EdgeInsets.all(8), child: Text('Name')),
            Padding(padding: EdgeInsets.all(8), child: Text('cm')),
            Padding(padding: EdgeInsets.all(8), child: Text('Sun')),
          ],
        ),
        for (final p in plants)
          TableRow(
            children: [
              Padding(padding: const EdgeInsets.all(8), child: Text(p.name)),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${p.heightCm}'),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(p.sun ? Icons.wb_sunny : Icons.cloud, size: 18),
              ),
            ],
          ),
      ],
    );
  }
}
// #enddocregion table

// #docregion datatable
/// DataTable with tap-to-sort columns. The widget draws a sort arrow, but
/// sorting the data is your job.
class SortableTable extends StatefulWidget {
  const SortableTable({super.key});

  @override
  State<SortableTable> createState() => _SortableTableState();
}

class _SortableTableState extends State<SortableTable> {
  final List<Plant> _rows = List.of(plants);
  int _sortColumn = 0;
  bool _ascending = true;

  void _sort<T extends Comparable<T>>(
    T Function(Plant p) key,
    int column,
    bool ascending,
  ) {
    setState(() {
      _rows.sort((a, b) {
        final result = key(a).compareTo(key(b));
        return ascending ? result : -result;
      });
      _sortColumn = column;
      _ascending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DataTable(
        sortColumnIndex: _sortColumn,
        sortAscending: _ascending,
        columns: [
          DataColumn(
            label: const Text('Name'),
            onSort: (i, asc) => _sort((p) => p.name, i, asc),
          ),
          DataColumn(
            label: const Text('Height (cm)'),
            numeric: true,
            onSort: (i, asc) => _sort((p) => p.heightCm, i, asc),
          ),
        ],
        rows: [
          for (final p in _rows)
            DataRow(
              cells: [DataCell(Text(p.name)), DataCell(Text('${p.heightCm}'))],
            ),
        ],
      ),
    );
  }
}
// #enddocregion datatable
