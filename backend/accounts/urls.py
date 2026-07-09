from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    RegisterView,
    LoginView,
    LogoutView,
    ProfileView,
    AccountDeleteView,
    SendOTPView,
    VerifyOTPView,
    PasswordResetRequestView,
    PasswordResetVerifyView,
    PasswordResetConfirmView,
    ChangePasswordView,
    # Admin views
    AdminUserListView,
    AdminToggleUserStatusView,
    AdminApproveOwnerView,
    AdminDashboardStatsView,
    AdminSystemLogsView,
    AdminOwnerDetailView,
    AdminOwnerCleanupView,
    OwnerDashboardStatsView,
    OwnerCashierView,
    OwnerCashierDetailView,
    # Registration query views
    SubmitRegistrationQueryView,
    AdminRegistrationQueryListView,
    AdminApproveOnboardView,
    AdminRejectQueryView,
    AdminRespondToQueryView,
    AdminNotificationCountView,
)

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("login/", LoginView.as_view(), name="login"),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("profile/", ProfileView.as_view(), name="profile"),
    path("delete/", AccountDeleteView.as_view(), name="delete"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("otp/send/", SendOTPView.as_view(), name="send-otp"),
    path("otp/verify/", VerifyOTPView.as_view(), name="verify-otp"),
    path("password/reset/", PasswordResetRequestView.as_view(), name="password-reset"),
    path("password/verify/", PasswordResetVerifyView.as_view(), name="password-verify"),
    path("password/confirm/", PasswordResetConfirmView.as_view(), name="password-confirm"),
    # Two paths, one view: parking-dashboard calls change-password/,
    # parkroo_app (Flutter) calls password/change/ — keep both working.
    path("change-password/", ChangePasswordView.as_view(), name="change-password"),
    path("password/change/", ChangePasswordView.as_view(), name="password-change"),

    # ── Public: Landing page query submission ──────────────────────────────
    path("registration-query/", SubmitRegistrationQueryView.as_view(), name="registration-query"),

    # ── Admin ──────────────────────────────────────────────────────────────
    path("admin/users/", AdminUserListView.as_view(), name="admin-user-list"),
    path("admin/users/<uuid:pk>/toggle/", AdminToggleUserStatusView.as_view(), name="admin-toggle-user"),
    path("admin/owners/<uuid:pk>/approve/", AdminApproveOwnerView.as_view(), name="admin-approve-owner"),
    path("admin/owners/<uuid:pk>/details/", AdminOwnerDetailView.as_view(), name="admin-owner-details"),
    path("admin/owner-cleanup/", AdminOwnerCleanupView.as_view(), name="admin-owner-cleanup"),
    path("admin/stats/", AdminDashboardStatsView.as_view(), name="admin-dashboard-stats"),
    path("admin/logs/", AdminSystemLogsView.as_view(), name="admin-system-logs"),

    # GET  /api/auth/admin/registration-queries/
    path("admin/registration-queries/", AdminRegistrationQueryListView.as_view(), name="admin-registration-queries"),

    # POST /api/auth/admin/queries/<id>/approve-onboard/
    path("admin/queries/<int:query_id>/approve-onboard/", AdminApproveOnboardView.as_view(), name="admin-approve-onboard"),

    # POST /api/auth/admin/queries/<id>/reject/
    path("admin/queries/<int:query_id>/reject/", AdminRejectQueryView.as_view(), name="admin-reject-query"),

    # POST /api/auth/admin/queries/<id>/respond/
    path("admin/queries/<int:query_id>/respond/", AdminRespondToQueryView.as_view(), name="admin-respond-query"),

    # GET /api/auth/admin/notifications/count/
    path("admin/notifications/count/", AdminNotificationCountView.as_view(), name="admin-notification-count"),

    # ── Owner endpoints ──
    path("owner/dashboard/", OwnerDashboardStatsView.as_view(), name="owner-dashboard-stats"),
    path("owner/cashiers/", OwnerCashierView.as_view(), name="owner-cashiers"),
    path("owner/cashiers/<uuid:cashier_id>/", OwnerCashierDetailView.as_view(), name="owner-cashier-detail"),
]