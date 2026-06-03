import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/support_ticket_model.dart';

class SupportProvider extends ChangeNotifier {
  // ── Student: support tickets ───────────────────────────────────────────────
  List<SupportTicketModel> _myTickets = [];
  bool    _loadingMyTickets = false;
  String? _myTicketsError;

  List<SupportTicketModel> get myTickets        => _myTickets;
  bool                     get loadingMyTickets => _loadingMyTickets;
  String?                  get myTicketsError   => _myTicketsError;

  // ── Student: material requests ─────────────────────────────────────────────
  List<SupportTicketModel> _myRequests = [];
  bool    _loadingMyRequests = false;
  String? _myRequestsError;

  List<SupportTicketModel> get myRequests        => _myRequests;
  bool                     get loadingMyRequests => _loadingMyRequests;
  String?                  get myRequestsError   => _myRequestsError;

  // ── Admin: support tickets ─────────────────────────────────────────────────
  List<SupportTicketModel> _adminTickets = [];
  bool    _loadingAdmin = false;
  String? _adminError;

  List<SupportTicketModel> get adminTickets => _adminTickets;
  bool                     get loadingAdmin => _loadingAdmin;
  String?                  get adminError   => _adminError;

  int get openCount        => _adminTickets.where((t) => t.status == 'open').length;
  int get underReviewCount => _adminTickets.where((t) => t.status == 'under_review').length;
  int get resolvedCount    => _adminTickets.where((t) => t.status == 'resolved').length;

  // ── Admin: material requests ───────────────────────────────────────────────
  List<SupportTicketModel> _adminRequests = [];
  bool    _loadingAdminRequests = false;
  String? _adminRequestsError;

  List<SupportTicketModel> get adminRequests        => _adminRequests;
  bool                     get loadingAdminRequests => _loadingAdminRequests;
  String?                  get adminRequestsError   => _adminRequestsError;

  int get pendingRequestCount   => _adminRequests.where((r) => r.status == 'pending').length;
  int get fulfilledRequestCount => _adminRequests.where((r) => r.status == 'fulfilled').length;

  // ── Student: fetch my support tickets ─────────────────────────────────────
  Future<void> fetchMyTickets() async {
    _loadingMyTickets = true;
    _myTicketsError   = null;
    notifyListeners();
    try {
      final data = await ApiClient.getMyTickets();
      _myTickets = data
          .map((j) => SupportTicketModel.fromJson(j as Map<String, dynamic>))
          .toList();
      dev.log('[SupportProvider] my tickets: ${_myTickets.length}');
    } catch (e) {
      _myTicketsError = 'Could not load your requests.';
      dev.log('[SupportProvider] fetchMyTickets error: $e');
    } finally {
      _loadingMyTickets = false;
      notifyListeners();
    }
  }

  // ── Student: fetch my material requests ────────────────────────────────────
  Future<void> fetchMyRequests() async {
    _loadingMyRequests = true;
    _myRequestsError   = null;
    notifyListeners();
    try {
      final data = await ApiClient.getMyMaterialRequests();
      _myRequests = data
          .map((j) => SupportTicketModel.fromJson(j as Map<String, dynamic>))
          .toList();
      dev.log('[SupportProvider] my requests: ${_myRequests.length}');
    } catch (e) {
      _myRequestsError = 'Could not load your requests.';
      dev.log('[SupportProvider] fetchMyRequests error: $e');
    } finally {
      _loadingMyRequests = false;
      notifyListeners();
    }
  }

  // ── Student: create support ticket ────────────────────────────────────────
  Future<String?> createTicket({
    required String title,
    required String message,
  }) async {
    try {
      await ApiClient.createSupportTicket(title: title, message: message);
      await fetchMyTickets();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Student: create material request ──────────────────────────────────────
  Future<String?> createMaterialRequest({
    required String title,
    required String message,
  }) async {
    try {
      await ApiClient.createMaterialRequest(title: title, message: message);
      await fetchMyRequests();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Admin: fetch support tickets ───────────────────────────────────────────
  Future<void> fetchAdminTickets({String? status}) async {
    _loadingAdmin = true;
    _adminError   = null;
    notifyListeners();
    try {
      final data = await ApiClient.getAdminTickets(status: status);
      _adminTickets = data
          .map((j) => SupportTicketModel.fromJson(j as Map<String, dynamic>))
          .toList();
      dev.log('[SupportProvider] admin tickets: ${_adminTickets.length}');
    } catch (e) {
      _adminError = 'Could not load tickets.';
      dev.log('[SupportProvider] fetchAdminTickets error: $e');
    } finally {
      _loadingAdmin = false;
      notifyListeners();
    }
  }

  // ── Admin: fetch material requests ─────────────────────────────────────────
  Future<void> fetchAdminRequests({String? status}) async {
    _loadingAdminRequests = true;
    _adminRequestsError   = null;
    notifyListeners();
    try {
      final data = await ApiClient.getAdminMaterialRequests(status: status);
      _adminRequests = data
          .map((j) => SupportTicketModel.fromJson(j as Map<String, dynamic>))
          .toList();
      dev.log('[SupportProvider] admin requests: ${_adminRequests.length}');
    } catch (e) {
      _adminRequestsError = 'Could not load requests.';
      dev.log('[SupportProvider] fetchAdminRequests error: $e');
    } finally {
      _loadingAdminRequests = false;
      notifyListeners();
    }
  }

  // ── Admin: update status (support) ────────────────────────────────────────
  Future<String?> updateStatus(int ticketId, String status) async {
    try {
      await ApiClient.updateTicketStatus(ticketId, status);
      final idx = _adminTickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) {
        _adminTickets[idx] = _adminTickets[idx].copyWith(
          status: status, updatedAt: DateTime.now());
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Admin: update status (material request) ────────────────────────────────
  Future<String?> updateRequestStatus(int ticketId, String status) async {
    try {
      await ApiClient.updateMaterialRequestStatus(ticketId, status);
      final idx = _adminRequests.indexWhere((r) => r.id == ticketId);
      if (idx != -1) {
        _adminRequests[idx] = _adminRequests[idx].copyWith(
          status: status, updatedAt: DateTime.now());
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Admin: reply (support) ─────────────────────────────────────────────────
  Future<String?> replyToTicket(int ticketId, String reply) async {
    try {
      await ApiClient.replyToTicket(ticketId, reply);
      await fetchAdminTickets();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Admin: reply (material request) ───────────────────────────────────────
  Future<String?> replyToRequest(int ticketId, String reply) async {
    try {
      await ApiClient.replyToMaterialRequest(ticketId, reply);
      await fetchAdminRequests();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Admin: delete (support) ────────────────────────────────────────────────
  Future<String?> deleteTicket(int ticketId) async {
    try {
      await ApiClient.deleteTicket(ticketId);
      _adminTickets.removeWhere((t) => t.id == ticketId);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Admin: delete (material request) ──────────────────────────────────────
  Future<String?> deleteRequest(int ticketId) async {
    try {
      await ApiClient.deleteMaterialRequest(ticketId);
      _adminRequests.removeWhere((r) => r.id == ticketId);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
