import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/models/clinic.dart';

void main() {
  group('rupees', () {
    test('uses Indian digit grouping', () {
      expect(rupees(125000), '₹1,25,000');
      expect(rupees(999), '₹999');
      expect(rupees(10000000), '₹1,00,00,000');
    });
    test('shows paise only when there are some', () {
      expect(rupees(450.5), '₹450.50');
      expect(rupees(450), '₹450');
    });
  });

  group('ClinicToday', () {
    test('parses buckets, dues and appointments', () {
      final t = ClinicToday.fromJson({
        'patients': 12,
        'followUps': {
          'overdue': [
            {'id': 1, 'clientId': 3, 'clientName': 'Ramesh', 'dueAt': 1, 'notifyPatient': true}
          ],
          'today': [],
          'upcoming': [],
        },
        'dues': [
          {'clientId': 3, 'name': 'Ramesh', 'balance': 500}
        ],
        'duesCount': 1,
        'duesTotal': 500,
        'appointments': [
          {'id': 9, 'patientName': 'Asha', 'startsAt': 1000, 'status': 'booked', 'source': 'receptionist'},
          {'id': 10, 'patientName': 'Ravi', 'startsAt': 2000, 'status': 'done'},
        ],
      });
      expect(t.patients, 12);
      expect(t.followUps.overdue.single.clientName, 'Ramesh');
      expect(t.followUps.overdue.single.notifyPatient, isTrue);
      expect(t.duesTotal, 500);
      expect(t.appointments.length, 2);
      expect(t.openAppointments.single.patientName, 'Asha');
      expect(t.openAppointments.single.source, 'receptionist');
    });
    test('survives a missing appointments field (older server)', () {
      final t = ClinicToday.fromJson({'patients': 0, 'followUps': null});
      expect(t.appointments, isEmpty);
      expect(t.followUps.isEmpty, isTrue);
    });
  });

  group('ClinicProfile', () {
    test('keeps only well-formed sessions and round-trips', () {
      final p = ClinicProfile.fromJson({
        'clinicName': 'Rao Clinic',
        'fee': 400,
        'hours': {
          'mon': [
            ['10:00', '13:00'],
            ['bad'],
          ],
        },
        'slotMin': 15,
        'configured': true,
      });
      expect(p.hours['mon'], [
        ['10:00', '13:00']
      ]);
      expect(p.hours['sun'], isEmpty);
      final j = p.toJson();
      expect(j['clinicName'], 'Rao Clinic');
      expect(j['fee'], 400);
      expect((j['hours'] as Map).length, 7);
    });
  });

  group('SoapNote', () {
    test('marks empty sections instead of leaving them blank', () {
      final n = SoapNote.fromJson({
        'subjective': 'Cough for 3 days',
        'assessment': 'URTI',
        'plan': 'Rest, fluids',
        'medications': [
          {'name': 'Paracetamol', 'dose': '650 mg', 'frequency': 'TDS', 'duration': '3 days', 'instructions': 'after food'},
        ],
        'followUpDays': 5,
        'redFlags': ['breathlessness'],
      });
      final t = n.toText();
      expect(t, contains('O: Not discussed.'));
      expect(t, contains('• Paracetamol 650 mg TDS × 3 days (after food)'));
      expect(t, contains('Watch for: breathlessness'));
      expect(t, contains('Review in 5 days.'));
    });
  });

  test('RxItem line skips empty parts', () {
    expect(RxItem(name: 'Pantoprazole', dose: '40 mg', frequency: 'OD').line,
        'Pantoprazole 40 mg OD');
  });

  group('advocates & business', () {
    test('Today carries hearings, leads and unpaid invoices', () {
      final t = ClinicToday.fromJson({
        'patients': 4,
        'followUps': {'overdue': [], 'today': [], 'upcoming': []},
        'hearingsToday': [
          {'id': 1, 'caseId': 7, 'caseTitle': 'Shetty vs Kumar', 'court': 'City Civil Court', 'at': 1000, 'status': 'upcoming'}
        ],
        'hearingsWeek': [],
        'leadsDue': [
          {'id': 3, 'name': 'Priya', 'company': 'Nair Exports', 'value': 1500000, 'stage': 'proposal'}
        ],
        'openLeads': 5,
        'pipelineValue': 4200000,
        'unpaidInvoices': 2,
        'unpaidTotal': 271400,
      });
      expect(t.hearingsToday.single.caseTitle, 'Shetty vs Kumar');
      expect(t.hearingsToday.single.court, 'City Civil Court');
      expect(t.leadsDue.single.company, 'Nair Exports');
      expect(t.pipelineValue, 4200000);
      expect(t.unpaidTotal, 271400);
    });
    test('an older server without these fields still parses', () {
      final t = ClinicToday.fromJson({'patients': 0, 'followUps': null});
      expect(t.hearingsToday, isEmpty);
      expect(t.leadsDue, isEmpty);
      expect(t.unpaidInvoices, 0);
    });
    test('invoice and lead shapes', () {
      final i = Invoice.fromJson({'id': 1, 'kind': 'quote', 'number': 'QT-0001', 'total': 500000, 'status': 'sent'});
      expect(i.isQuote, isTrue);
      expect(i.isPaid, isFalse);
      final l = Lead.fromJson({'id': 2, 'name': 'Ravi', 'stage': 'won', 'clientId': 9});
      expect(l.stage, 'won');
      expect(l.clientId, 9);
      expect(InvoiceLine(description: 'x', qty: 3, rate: 2500).amount, 7500);
    });
    test('a case without a next hearing is fine', () {
      final c = LegalCase.fromJson({'id': 1, 'title': 'A vs B', 'nextHearingAt': null});
      expect(c.nextHearingAt, isNull);
      expect(c.status, 'open');
    });
  });
}
