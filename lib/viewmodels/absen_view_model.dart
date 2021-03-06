import 'dart:io';

import 'package:pklonline/constants/const.dart';
import 'package:pklonline/constants/route_name.dart';
import 'package:pklonline/locator.dart';
import 'package:pklonline/models/send_absen.dart';
import 'package:pklonline/services/alert_service.dart';
import 'package:pklonline/services/api_service.dart';
import 'package:pklonline/services/ftp_service.dart';
import 'package:pklonline/services/geolocator_service.dart';
import 'package:pklonline/services/location_service.dart';
import 'package:pklonline/services/navigation_service.dart';
import 'package:pklonline/services/rmq_service.dart';
import 'package:pklonline/services/storage_service.dart';
import 'package:pklonline/viewmodels/base_model.dart';
import 'package:flutter/cupertino.dart';

class AbsenViewModel extends BaseModel {
  final NavigationService _navigationService = locator<NavigationService>();
  final GeolocatorService _geolocatorService = locator<GeolocatorService>();
  final ApiService _apiService = locator<ApiService>();
  final StorageService _storageService = locator<StorageService>();
  final AlertService _alertService = locator<AlertService>();
  final FtpService _ftpService = locator<FtpService>();
  final RMQService _rmqService = locator<RMQService>();
  final LocationService _locationService = locator<LocationService>();

  String imagePath = '';
  String imageName = '';
  double lat = 0.0;
  double lng = 0.0;
  String address = '';
  String pathLocation = 'data/kehadiran/image/';

  String kindOfReport = '#Laporan Kehadiran';
  TextEditingController commentController = TextEditingController();

  void getValueRadio(int value) {
    switch (value) {
      case 1:
        kindOfReport = '#Laporan Kehadiran';
        break;
      case 2:
        kindOfReport = '#Laporan Tugas/PKL';
        break;
      case 3:
        kindOfReport = '#Laporan Mobilitas';
        break;
      default:
        {
          kindOfReport = '#Tidak Ada Laporan Khusus';
        }
        break;
    }
  }

  Future<void> cameraView() async {
    try {
      final path = await _navigationService.navigateTo(CameraViewRoute);
      var words = path.split('#');
      imagePath = words[0];
      imageName = words[1];

      await getLocation();
      print(imagePath);
    } on NoSuchMethodError catch (ne) {
      throw StateError(
          'On Back Pressed after no capture photo: ' + ne.toString());
    } on NullThrownError catch (nue) {
      throw StateError('NullThrownError: ' + nue.toString());
    } on Exception catch (e) {
      throw StateError('Other Error: ' + e.toString());
    }
  }

  void openLocationSetting() async {
    // final AndroidIntent intent = new AndroidIntent(
    //   action: 'android.settings.LOCATION_SOURCE_SETTINGS',
    // );
    // await intent.launch();
    await _locationService.checkService();
  }

  void sendMessages(BuildContext context) async {
    setBusy(true);

    final date = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = date.substring(0, 10);
    final name = await _storageService.getString(K_NAME);
    final company = await _storageService.getString(K_COMPANY);
    final unit = await _storageService.getString(K_UNIT);
    final guid = await _storageService.getString(K_GUID);
    print("ini tanggal ${timestamp}");
    bool isSuccess =
        await _ftpService.uploadFile(File(imagePath), guid, timestamp);

    if (isSuccess) {
      var absenData = SendAbsen(
          address: '$address',
          cmdType: 0,
          company: '$company',
          description: '#PKL Online${kindOfReport}#${commentController.text}',
          guid: '$guid',
          image: '$pathLocation$guid$timestamp-PPTIK.jpg',
          lat: '$lat',
          long: '$lng',
          localImage: '$imagePath',
          msgType: 1,
          name: '$name',
          status: 'HADIR',
          timestamp: '$timestamp',
          unit: '$unit');

      final sendAbsen = sendAbsenToJson(absenData);

      _rmqService.publish(sendAbsen);

      _alertService.showSuccess(
        context,
        'Success',
        '',
        () {
          _navigationService.replaceTo(HomeViewRoute);
        },
      );
    } else {
      //
      _alertService.showWarning(context, 'Warning',
          'Connection to server problem', _navigationService.pop);
    }

    setBusy(false);
  }

  void absent(BuildContext context) async {
    setBusy(true);

    final company = await _storageService.getString(K_COMPANY);
    final guid = await _storageService.getString(K_GUID);
    final name = await _storageService.getString(K_NAME);
    final desc = commentController.text;
    final status = "Hadir";
    final position = await _storageService.getString(K_POSITION);
    final unit = await _storageService.getString(K_UNIT);
    final date = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = date.substring(0, 10);

    final data = await _apiService.report(
        pathLocation + guid + '-' + imagePath,
        company,
        guid,
        name,
        '$lng',
        '$lat',
        address,
        status,
        position,
        unit,
        timestamp,
        desc,
        File(imagePath));

    if (data != null) {
      _alertService.showSuccess(
        context,
        'Succes',
        '',
        () {
          _navigationService.pop();
        },
      );
    } else {
      _alertService.showWarning(context, 'Warning',
          'Connection to server problem', _navigationService.pop);
    }
    setBusy(false);
  }

  bool isPathNull() {
    if (imagePath == null || imagePath.isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> getLocation() async {
    setBusy(true);
    try {
      final userLocation = await _geolocatorService.getCurrentLocation();
      lat = userLocation.latitude;
      lng = userLocation.longitude;
      address = userLocation.addressLine;
      setBusy(false);
    } catch (e) {
      setBusy(false);

      cameraView();
    }
  }
}
