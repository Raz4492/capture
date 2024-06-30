import 'package:capturesdk_flutter/capturesdk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

class ScannedDataCubit extends Cubit<List<DecodedData>> {
  final _decodedDataSubject = BehaviorSubject<List<DecodedData>>.seeded([]);

  ScannedDataCubit() : super([]);

  Stream<List<DecodedData>> get decodedDataStream => _decodedDataSubject.stream;

  void addDecodedData(DecodedData data) {
    final currentList = _decodedDataSubject.value;
    _decodedDataSubject.add([...currentList, data]);
  }

  void clearAllData() {
    _decodedDataSubject.add([]);
  }

  @override
  Future<void> close() {
    _decodedDataSubject.close();
    return super.close();
  }
}
