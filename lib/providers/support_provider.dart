import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/support_ticket_model.dart';

class SupportProvider extends ChangeNotifier {
  // ── Student state ──────────────────────────────────────────────────────────
  List<SupportTicketModel> _myTickets = [];
  bool    _loadingMyTickets = false;
  String? _myTicketsError;

  List<SupportTicketModel> get myTickets        => _myTickets;
  bool                     get loadingMyTickets => _loadingMyTickets;
  String?                  get myTicketsError   => _myTicketsError;

  // ── Admin state ────────────────────────────────────────────────────────────
  List<SupportTicketModel> _adminTickets = [];
  bool    _loadingAdmin = false;
  String? _adminError;

  List<SupportTicketModel> get adminTickets  => _adminTickets;
  bool                     get loadingAdmin  => _loadingAdmin;
  String?                  get adminError    => _adminError;

  int get openCount       => _adminTickets.where((t) => t.status == 'open').length;
  int get underReviewCount => _adminTickets.where((t) => t.status == 'under_review').length;
  int get resolvedCount   => _adminTickets.where((t) => t.status == 'resolved').length;

  // ── Student: fetch my tickets ──────────────────────────────────────────────
  Future<void> fetchMyTickets() async {
    _loadingMyTickets = true;
    _myTicketsError   = null;
    notifyListeners();
    try {
      final data = await ApiClient.getMyTickets();
      _myTickets = data
          .map((j) => SupportTicketModel.fromJson(j as Map<String, dynamic>))
          .toList();
      dev.log('[SupportProvider] loaded ${_myTickets.length} my tickets',
          name: 'SupportProvider');
    } catch (e) {
      _myTicketsError = 'Could not load your requests.';
      dev.log('[SupportProvider] fetchMyTickets error: $e', name: 'SupportProvider');
    } finally {
      _loadingMyTickets = false;
      notifyListeners();
    }
  }

  // ── Student: create ticket ─────────────────────────────────────────────────
  Future<String?> createTicket({
    required String title,
    required String message,
  }) async {
    try {
      await ApiClient.createSupportTicket(title: title, message: message);
      await fetchMyTickets();
      return null; // null = success
    } catch (e) {
      return e.toString();
    }
  }

  // ── Admin: fetch all tickets ───────────────────────────────────────────────
  Future<void> fetchAdminTickets({String? status}) async {
    _loadingAdmin = true;
    _adminError   = null;
    notifyListeners();
    try {
      final data = await ApiClient.getAdminTickets(status: status);
      _adminTickets = data
          .map((j) => SupportTicketModel.fromJson(j as Map<String, dynamic>))
          .toList();
      dev.log('[SupportProvider] admin loaded ${_adminTickets.length} tickets',
          name: 'SupportProvider');
    } catch (e) {
      _adminError = 'Could not load tickets.';
      dev.log('[SupportProvider] fetchAdminTickets error: $e', name: 'SupportProvider');
    } finally {
      _loadingAdmin = false;
      notifyListeners();
    }
  }

  // ── Admin: update status ───────────────────────────────────────────────────
  Future<String?> updateStatus(int ticketId, String status) async {
    try {
      await ApiClient.updateTicketStatus(ticketId, status);
      // Update local state immediately
      final idx = _adminTickets.indexWhere((t) => t.id == ticketId);
      if (idx != -1) {
        final old = _adminTickets[idx];
        _adminTickets[idx] = SupportTicketModel(
          id: old.id, title: old.title, message: old.message,
          status: status, adminReply: old.adminReply,
          repliedAt: old.repliedAt, createdAt: old.createdAt,
          updatedAt: DateTime.now(),
          studentName: old.studentName, studentEmail: old.studentEmail,
        );
        notifyListeners();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Admin: reply ───────────────────────────────────────────────────────────
  Future<String?> replyToTicket(int ticketId, String reply) async {
    try {
      await ApiClient.replyToTicket(ticketId, reply);
      await fetchAdminTickets();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
