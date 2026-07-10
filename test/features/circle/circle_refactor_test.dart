import 'package:flutter_test/flutter_test.dart';
import 'package:memory_app/features/circle/circle.dart';

void main() {
  group('Circle & Social Refactor Tests', () {
    test('CircleMember.fromJson parses roles and status correctly', () {
      final jsonOwner = {
        'id': 'user-1',
        'username': 'owner_user',
        'firstName': 'Owner',
        'role': 'owner',
        'status': 'member',
      };
      final jsonAdmin = {
        'id': 'user-2',
        'username': 'admin_user',
        'firstName': 'Admin',
        'role': 'admin',
        'status': 'pending',
      };

      final memberOwner = CircleMember.fromJson(jsonOwner);
      final memberAdmin = CircleMember.fromJson(jsonAdmin);

      expect(memberOwner.role, CircleRole.owner);
      expect(memberOwner.relationshipState, RelationshipState.member);

      expect(memberAdmin.role, CircleRole.admin);
      expect(memberAdmin.relationshipState, RelationshipState.pending);
    });

    test('RelationshipState enum values are correct', () {
      expect(RelationshipState.values.length, 5);
      expect(RelationshipState.unknown.index, 0);
      expect(RelationshipState.notConnected.index, 1);
      expect(RelationshipState.pending.index, 2);
      expect(RelationshipState.member.index, 3);
      expect(RelationshipState.removed.index, 4);
    });

    test('CircleRole enum values are correct', () {
      expect(CircleRole.values.length, 4);
      expect(CircleRole.owner.index, 0);
      expect(CircleRole.admin.index, 1);
      expect(CircleRole.moderator.index, 2);
      expect(CircleRole.member.index, 3);
    });
  });
}
