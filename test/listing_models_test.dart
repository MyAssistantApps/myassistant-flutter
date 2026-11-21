import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/models/listing.dart';

void main() {
  group('parseLatLng', () {
    test('reads the common Google Maps link shapes', () {
      expect(parseLatLng('https://www.google.com/maps/place/X/@12.8714,74.8432,17z'), (lat: 12.8714, lng: 74.8432));
      expect(parseLatLng('https://maps.google.com/?q=12.87,74.84'), (lat: 12.87, lng: 74.84));
      expect(parseLatLng('https://www.google.com/maps/place/X/data=!3d12.871!4d74.843'), (lat: 12.871, lng: 74.843));
      expect(parseLatLng(' 12.8714, 74.8432 '), (lat: 12.8714, lng: 74.8432));
    });
    test('refuses links without a location and nonsense pairs', () {
      expect(parseLatLng('https://maps.app.goo.gl/abc123'), isNull);
      expect(parseLatLng('0.0, 0.0'), isNull);
      expect(parseLatLng('hello'), isNull);
    });
  });

  test('distance labels', () {
    expect(distanceLabel(0.34), '340 m');
    expect(distanceLabel(1.26), '1.3 km');
    expect(distanceLabel(23.4), '23 km');
    expect(distanceLabel(null), '');
  });

  test('listing state: missing items and post kinds', () {
    final s = ListingState.fromJson({
      'listing': {'persona': 'doctor', 'displayName': 'Dr. Rao', 'draft': true, 'services': ['Braces']},
      'url': null,
      'missing': ['location', 'reg_no'],
      'postKinds': ['update'],
      'newRequests': 2,
      'clinic': {'regNo': '', 'hours': 'Mon–Sat 10am–1pm'},
    });
    expect(s.listing.draft, isTrue);
    expect(s.listing.hasPin, isFalse);
    expect(s.ready, isFalse);
    expect(s.canPost, isTrue);
    expect(s.newRequests, 2);
    expect(s.missing.map(missingLabel), ['Map pin', 'Medical registration number']);
  });

  test('a business card leads with the shop name', () {
    final c = ProCard.fromJson({
      'slug': 's', 'persona': 'business', 'displayName': 'Ravi', 'placeName': 'Ravi Silks',
      'headline': 'Sarees', 'area': 'Kadri', 'city': 'Mangaluru', 'distanceKm': 0.8,
      'posts': [{'id': 1, 'kind': 'offer', 'title': '20% off'}],
    });
    expect(c.title, 'Ravi Silks');
    expect(c.subtitle, 'Ravi · Sarees');
    expect(c.where, 'Kadri, Mangaluru');
    expect(c.posts.single.isOffer, isTrue);
    final d = ProCard.fromJson({'slug': 'd', 'persona': 'doctor', 'displayName': 'Dr. Asha', 'headline': 'Dentist', 'placeName': 'Smile Clinic'});
    expect(d.title, 'Dr. Asha');
    expect(d.subtitle, 'Dentist · Smile Clinic');
  });
}
