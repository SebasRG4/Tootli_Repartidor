import 'package:get/get_connect/http/src/response/response.dart';
import 'package:sixam_mart_delivery/api/api_client.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'mission_repository_interface.dart';

class MissionRepository implements MissionRepositoryInterface {
  final ApiClient apiClient;
  MissionRepository({required this.apiClient});

  @override
  Future<Response> getMissionList() async {
    return await apiClient.getData(AppConstants.missionUri);
  }
}
