import 'package:get/get_connect/http/src/response/response.dart';
import '../repositories/mission_repository_interface.dart';
import 'mission_service_interface.dart';

class MissionService implements MissionServiceInterface {
  final MissionRepositoryInterface missionRepositoryInterface;
  MissionService({required this.missionRepositoryInterface});

  @override
  Future<Response> getMissionList() async {
    return await missionRepositoryInterface.getMissionList();
  }
}
