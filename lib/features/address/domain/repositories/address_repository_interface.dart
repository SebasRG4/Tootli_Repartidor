import 'package:sixam_mart_delivery/interface/repository_interface.dart';

abstract class AddressRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getZone(String lat, String lng);
  Future<dynamic> getGridList(int zoneId);
  String? getUserAddress();
  Future<bool> saveUserAddress(String address, List<int>? zoneIDs);
}
