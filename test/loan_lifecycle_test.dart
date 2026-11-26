import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/loans/data/loan_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mx.edu.uttec.labcontrol/inventory');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'listLoanEvents') {
        return [
          {
            'id': 1,
            'type': 'incident',
            'detail': 'Cable dañado',
            'createdAt': 4000,
            'oldDueAt': null,
            'newDueAt': null,
          },
        ];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Loan makeLoan({int? dueAt, int? returnedAt}) => Loan.fromMap({
    'id': 4,
    'code': 'DTIC-4',
    'name': 'Laptop',
    'borrower': 'Ana',
    'destination': '',
    'lentAt': 1000,
    'returnedAt': returnedAt,
    'dueAt': dueAt,
  });

  test('Detecta vencimiento solo para préstamos activos con fecha límite', () {
    expect(makeLoan(dueAt: 2000).isOverdue(
      DateTime.fromMillisecondsSinceEpoch(3000)), isTrue);
    expect(makeLoan(dueAt: 2000, returnedAt: 2500).isOverdue(
      DateTime.fromMillisecondsSinceEpoch(3000)), isFalse);
    expect(makeLoan().isOverdue(DateTime.now()), isFalse);
    expect(makeLoan(dueAt: 5000).isOverdue(
      DateTime.fromMillisecondsSinceEpoch(3000)), isFalse);
  });

  test('Envía plazos, prórrogas e incidencias al canal SQLite', () async {
    const store = LoanStore();
    final deadline = DateTime(2030, 12, 4, 23, 59, 59, 999);
    await store.lend('DTIC-4', 'Ana', 'Lab', dueAt: deadline);
    await store.extend(4, deadline, 'Laboratorio ocupado');
    await store.addIncident(4, 'Cable dañado');
    final events = await store.listEvents(4);

    expect(calls.map((call) => call.method), [
      'lend', 'extendLoan', 'addLoanIncident', 'listLoanEvents',
    ]);
    expect((calls[0].arguments as Map)['dueAt'], deadline.millisecondsSinceEpoch);
    expect((calls[1].arguments as Map)['reason'], 'Laboratorio ocupado');
    expect((calls[2].arguments as Map)['id'], 4);
    expect(events.single.detail, 'Cable dañado');
    expect(events.single.type, 'incident');
    expect(events.single.newDueAt, isNull);
  });

  test('Un préstamo antiguo sin dueAt sigue siendo válido', () {
    final loan = makeLoan();
    expect(loan.id, 4);
    expect(loan.dueAt, isNull);
    expect(loan.returnedAt, isNull);
  });
}
