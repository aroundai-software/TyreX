/// Model for owner_master table
class OwnerMasterModel {
  final String? id;
  final String ownerName;
  final String? alias;
  final String? alias1;
  final String? alias2;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String? state;
  final String? country;
  final String? pincode;
  final String? phoneNumber;
  final String? mobileNumber;
  final String? email;
  final String? panNumber;
  final String? gstNumber;
  final String? masterId;
  final String? guid;

  OwnerMasterModel({
    this.id,
    required this.ownerName,
    this.alias,
    this.alias1,
    this.alias2,
    this.addressLine1,
    this.addressLine2,
    this.addressLine3,
    this.state,
    this.country,
    this.pincode,
    this.phoneNumber,
    this.mobileNumber,
    this.email,
    this.panNumber,
    this.gstNumber,
    this.masterId,
    this.guid,
  });

  /// Convert model to JSON for database insertion
  Map<String, dynamic> toJson() {
    return {
      'Owner name': ownerName,
      'alias': alias,
      'alias1': alias1,
      'alias2': alias2,
      'Address Line1': addressLine1,
      'Address Line2': addressLine2,
      'Address Line3': addressLine3,
      'state': state,
      'country': country ?? 'India',
      'pincode': pincode,
      'PhoneNumber': phoneNumber,
      'MobileNumber': mobileNumber,
      'email': email,
      'pannumber': panNumber,
      'GST Number': gstNumber,
      // MasterID and Guid are auto-filled by Tally, so we don't set them
    };
  }

  /// Create model from JSON
  factory OwnerMasterModel.fromJson(Map<String, dynamic> json) {
    return OwnerMasterModel(
      id: json['id'] as String?,
      ownerName: json['Owner name'] as String? ?? '',
      alias: json['alias'] as String?,
      alias1: json['alias1'] as String?,
      alias2: json['alias2'] as String?,
      addressLine1: json['Address Line1'] as String?,
      addressLine2: json['Address Line2'] as String?,
      addressLine3: json['Address Line3'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      pincode: json['pincode'] as String?,
      phoneNumber: json['PhoneNumber'] as String?,
      mobileNumber: json['MobileNumber'] as String?,
      email: json['email'] as String?,
      panNumber: json['pannumber'] as String?,
      gstNumber: json['GST Number'] as String?,
      masterId: json['MasterID'] as String?,
      guid: json['Guid'] as String?,
    );
  }
}
