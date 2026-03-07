import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/address/domain/models/address_model.dart';
import 'package:sixam_mart_delivery/features/address/domain/models/zone_model.dart';
import 'package:sixam_mart_delivery/features/address/domain/models/zone_response_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/helper/grid_helper.dart';
import 'package:sixam_mart_delivery/features/address/domain/services/address_service_interface.dart';
import 'package:sixam_mart_delivery/helper/marker_helper.dart';

class AddressController extends GetxController implements GetxService {
  final AddressServiceInterface addressServiceInterface;
  AddressController({required this.addressServiceInterface});

  XFile? _pickedLogo;
  XFile? get pickedLogo => _pickedLogo;

  XFile? _pickedCover;
  XFile? get pickedCover => _pickedCover;

  List<ZoneModel>? _zoneList;
  List<ZoneModel>? get zoneList => _zoneList;

  int? _selectedZoneIndex = 0;
  int? get selectedZoneIndex => _selectedZoneIndex;

  List<int>? _zoneIds;
  List<int>? get zoneIds => _zoneIds;

  List<dynamic>? _gridList;
  List<dynamic>? get gridList => _gridList;

  Set<Polygon> _gridPolygons = {};
  Set<Polygon> get gridPolygons => _gridPolygons;

  Set<Marker> _gridMarkers = {};
  Set<Marker> get gridMarkers => _gridMarkers;

  bool _loading = false;
  bool get loading => _loading;

  bool _inZone = false;
  bool get inZone => _inZone;

  int _zoneID = 0;
  int get zoneID => _zoneID;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _selectedDeliveryZoneId;
  String? get selectedDeliveryZoneId => _selectedDeliveryZoneId;

  Future<void> getZoneList() async {
    _pickedLogo = null;
    _pickedCover = null;
    _selectedZoneIndex = 0;
    _zoneIds = null;
    List<ZoneModel>? zoneList = await addressServiceInterface.getZoneList();
    if (zoneList != null) {
      _zoneList = [];
      _zoneList!.addAll(zoneList);
    }
    update();
  }

  Future<void> getGridList(int zoneId) async {
    _gridList = null;
    _gridPolygons = {};
    _gridMarkers = {};
    Response response = await addressServiceInterface.getGridList(zoneId);
    if (response.statusCode == 200) {
      _gridList = [];
      final dynamic body = response.body;
      List<dynamic> gridData = [];
      if (body is List) {
        gridData = body;
      } else if (body is String) {
        gridData = jsonDecode(body);
      }

      for (var grid in gridData) {
        _gridList!.add(grid);

        try {
          String hexId = grid['hexagon_id'].toString();
          double surgeAmount =
              double.tryParse(grid['surge_amount'].toString()) ?? 0;

          if (surgeAmount > 0) {
            List<LatLng> points = GridHelper.getHexagonPoints(hexId);
            Color baseColor = surgeAmount >= 20
                ? Colors.red
                : Colors.orangeAccent;

            // Add the "Geofence" Polygon
            if (points.isNotEmpty) {
              _gridPolygons.add(
                Polygon(
                  polygonId: PolygonId('geofence_$hexId'),
                  points: points,
                  strokeWidth: 4,
                  strokeColor: baseColor,
                  fillColor: baseColor.withOpacity(0.12),
                ),
              );
            }

            // Add the Custom Pill Marker
            if (grid['center'] != null) {
              double lat = double.parse(grid['center']['lat'].toString());
              double lng = double.parse(grid['center']['lng'].toString());

              _gridMarkers.add(
                Marker(
                  markerId: MarkerId('surge_marker_$hexId'),
                  position: LatLng(lat, lng),
                  anchor: const Offset(0.5, 0.5), // Center the flat marker
                  icon: await MarkerHelper.createCustomMarkerBitmap(
                    '+MX\$${surgeAmount.toStringAsFixed(0)}',
                    color: baseColor,
                  ),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error processing grid incentive: $e');
        }
      }
    } else {
      debugPrint('Grid API Failed with body: ${response.body}');
    }
    update();
  }

  void setSelectedDeliveryZone({String? zoneId}) {
    _selectedDeliveryZoneId = zoneId;
    update();
  }

  void resetSelectedDeliveryZone() {
    _selectedDeliveryZoneId = null;
  }

  Future<ZoneResponseModel?> getZone(
    String lat,
    String long,
    bool markerLoad, {
    bool updateInAddress = false,
  }) async {
    markerLoad ? _loading = true : _isLoading = true;
    if (!updateInAddress) {
      update();
    }
    ZoneResponseModel? responseModel;
    Response response = await addressServiceInterface.getZone(lat, long);
    if (response.statusCode == 200) {
      _inZone = true;
      _zoneID = int.parse(jsonDecode(response.body['zone_id'])[0].toString());
      List<int> zoneIds = [];
      jsonDecode(response.body['zone_id']).forEach((zoneId) {
        zoneIds.add(int.parse(zoneId.toString()));
      });
    } else {
      _inZone = false;
      responseModel = ZoneResponseModel(false, response.statusText, [], []);
    }
    markerLoad ? _loading = false : _isLoading = false;
    update();
    return responseModel;
  }

  AddressModel? getUserAddress() {
    AddressModel? addressModel;
    try {
      addressModel = AddressModel.fromJson(
        jsonDecode(addressServiceInterface.getUserAddress()!),
      );
    } catch (e) {
      debugPrint('Address Not Found In SharedPreference:$e');
    }
    return addressModel;
  }

  Future<bool> saveUserAddress(AddressModel address) async {
    String userAddress = jsonEncode(address.toJson());
    return await addressServiceInterface.saveUserAddress(
      userAddress,
      address.zoneIds,
    );
  }

  double getRestaurantDistance(LatLng storeLatLng, {LatLng? customerLatLng}) {
    double distance = 0;
    distance =
        Geolocator.distanceBetween(
          storeLatLng.latitude,
          storeLatLng.longitude,
          customerLatLng?.latitude ??
              Get.find<ProfileController>().recordLocationBody?.latitude ??
              0,
          customerLatLng?.longitude ??
              Get.find<ProfileController>().recordLocationBody?.longitude ??
              0,
        ) /
        1000;
    return distance;
  }
}
