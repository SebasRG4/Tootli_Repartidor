import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/mission/domain/models/mission_model.dart';
import '../domain/services/mission_service_interface.dart';

class MissionController extends GetxController implements GetxService {
  final MissionServiceInterface missionServiceInterface;
  MissionController({required this.missionServiceInterface});

  List<MissionModel>? _missionList;
  List<MissionModel>? get missionList => _missionList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> getMissionList() async {
    _isLoading = true;
    update();

    Response response = await missionServiceInterface.getMissionList();
    if (response.statusCode == 200) {
      _missionList = [];
      response.body.forEach((mission) {
        _missionList!.add(MissionModel.fromJson(mission));
      });
    } else {
      // Handle error
    }

    _isLoading = false;
    update();
  }
}
