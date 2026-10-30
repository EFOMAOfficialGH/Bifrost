import 'package:flutter_test/flutter_test.dart';
import 'package:bifrost/core/storage/app_storage.dart';
import 'package:bifrost/features/history/history_filter.dart';

void main() {
  final now = DateTime(2026, 10, 30, 12);
  final records = [
    TransferRecord(
      id: '1',
      fileName: 'Family photo.jpg',
      bytes: 100,
      direction: 'Received',
      status: 'Completed',
      peer: 'Kitchen phone',
      time: DateTime(2026, 10, 30, 9),
    ),
    TransferRecord(
      id: '2',
      fileName: 'budget.xlsx',
      bytes: 200,
      direction: 'Sent',
      status: 'Completed',
      peer: 'Office PC',
      time: DateTime(2026, 10, 25, 9),
    ),
    TransferRecord(
      id: '3',
      fileName: 'movie.mp4',
      bytes: 300,
      direction: 'Received',
      status: 'Failed',
      peer: 'Living room PC',
      time: DateTime(2026, 9, 20, 9),
    ),
  ];

  test(
    'history search matches file name, device, date, and file extension',
    () {
      expect(
        filterTransferHistory(
          records,
          query: 'family',
          now: now,
        ).map((item) => item.id),
        ['1'],
      );
      expect(
        filterTransferHistory(
          records,
          query: 'office pc',
          now: now,
        ).map((item) => item.id),
        ['2'],
      );
      expect(
        filterTransferHistory(
          records,
          query: '2026-10-25',
          now: now,
        ).map((item) => item.id),
        ['2'],
      );
      expect(
        filterTransferHistory(
          records,
          query: '.mp4',
          now: now,
        ).map((item) => item.id),
        ['3'],
      );
    },
  );

  test('history category and recency filters compose', () {
    expect(
      filterTransferHistory(
        records,
        category: TransferHistoryCategory.images,
        now: now,
      ).map((item) => item.id),
      ['1'],
    );
    expect(
      filterTransferHistory(
        records,
        period: TransferHistoryPeriod.last7Days,
        now: now,
      ).map((item) => item.id),
      ['1', '2'],
    );
    expect(
      filterTransferHistory(
        records,
        category: TransferHistoryCategory.documents,
        period: TransferHistoryPeriod.today,
        now: now,
      ),
      isEmpty,
    );
  });
}
