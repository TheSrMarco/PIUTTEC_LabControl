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
          if (call.method == 'lendMany') return 101;
          if (call.method == 'listLoans') {
            return [
              {
                'id': 101,
                'folio': 101,
                'code': 'DTIC-A',
                'name': 'Laptop A',
                'borrower': 'Ana',
                'destination': 'UTTEC',
                'lentAt': 2000,
                'returnedAt': null,
                'dueAt': null,
              },
              {
                'id': 102,
                'folio': 101,
                'code': 'DTIC-B',
                'name': 'Laptop B',
                'borrower': 'Ana',
                'destination': 'UTTEC',
                'lentAt': 2000,
                'returnedAt': null,
                'dueAt': null,
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

  test('Envía múltiples códigos y obtiene un folio compartido', () async {
    const store = LoanStore();
    final dueDate = DateTime(2030, 5, 12, 23, 59);
    final folio = await store.lendMany(
      ['DTIC-A', 'DTIC-B'],
      'Ana',
      'UTTEC',
      dueAt: dueDate,
    );
    expect(folio, 101);
    expect(calls.single.method, 'lendMany');
    final args = calls.single.arguments as Map;
    expect(args['codes'], ['DTIC-A', 'DTIC-B']);
    expect(args['borrower'], 'Ana');
    expect(args['dueAt'], dueDate.millisecondsSinceEpoch);
  });

  test('Consulta y devuelve cada equipo por ID, no por folio', () async {
    const store = LoanStore();
    final entries = await store.list();
    expect(entries, hasLength(2));
    expect(entries.first.folio, 101);
    expect(entries.last.folio, 101);
    expect(entries.first.id, 101);
    expect(entries.last.id, 102);

    await store.returnLoan(102);
    expect(calls.last.method, 'returnLoan');
    expect((calls.last.arguments as Map)['id'], 102);
  });
}
