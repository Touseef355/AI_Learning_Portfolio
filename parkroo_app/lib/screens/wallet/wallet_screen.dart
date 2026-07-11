import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_shadows.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../services/payment/payment_service.dart';
import '../../services/payment/payment_gateway_interface.dart';
import '../payment/payment_webview_screen.dart';
import '../../widgets/common/pk_button.dart';
import '../../widgets/common/pk_skeleton.dart';
import '../../widgets/common/micro_animations.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  double _balance = 0.0;
  List<dynamic> _transactions = [];
  String? _error;

  late final AnimationController _balanceCtrl;
  late final Animation<double> _balanceFade;
  late final Animation<double> _balanceScale;

  @override
  void initState() {
    super.initState();
    _balanceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _balanceFade = CurvedAnimation(parent: _balanceCtrl, curve: Curves.easeOut);
    _balanceScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _balanceCtrl, curve: Curves.easeOutBack),
    );
    _loadWallet();
  }

  @override
  void dispose() {
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final data = await ApiService.getWallet();
    if (!mounted) return;
    if (data['error'] != null) {
      setState(() {
        _error = data['error'].toString();
        _isLoading = false;
      });
    } else {
      setState(() {
        _balance = double.tryParse(data['balance'].toString()) ?? 0.0;
        _transactions = data['transactions'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
      _balanceCtrl.forward(from: 0);
    }
  }

  void _showTopUpSheet() {
    HapticFeedback.mediumImpact();
    final amountCtrl = TextEditingController();
    int? selectedAmt;
    bool isSaving = false;
    final amounts = [500, 1000, 2000, 5000];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.of(context).bgCard,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                    color: AppColors.of(context).border.withOpacity(0.5)),
              ),
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.of(context).border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Top Up Wallet',
                      style: AppTextStyles.h3.copyWith(
                          color: AppColors.of(context).textPrimary)),
                  const SizedBox(height: 6),
                  Text('Add funds to pay for parking instantly',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.of(context).textHint)),
                  const SizedBox(height: 24),

                  // Quick amount chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: amounts
                        .map((amt) => GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setSheet(() {
                                  selectedAmt = amt;
                                  amountCtrl.text = amt.toString();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: selectedAmt == amt
                                      ? AppColors.primary.withOpacity(0.15)
                                      : AppColors.of(context).bgElevated,
                                  borderRadius: BorderRadius.circular(
                                      AppConstants.radiusMd),
                                  border: Border.all(
                                    color: selectedAmt == amt
                                        ? AppColors.primary.withOpacity(0.5)
                                        : AppColors.of(context).border,
                                    width: selectedAmt == amt ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  'PKR $amt',
                                  style: AppTextStyles.labelLg.copyWith(
                                    color: selectedAmt == amt
                                        ? AppColors.primary
                                        : AppColors.of(context).textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // Custom amount
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheet(() => selectedAmt = null),
                    style: AppTextStyles.bodyLg
                        .copyWith(color: AppColors.of(context).textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Custom Amount (PKR)',
                      labelStyle: AppTextStyles.labelMd
                          .copyWith(color: AppColors.of(context).textHint),
                      prefixIcon: Icon(Icons.payments_outlined,
                          color: AppColors.of(context).textHint, size: 20),
                      filled: true,
                      fillColor: AppColors.of(context).bgElevated,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide(
                              color: AppColors.of(context).border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide(
                              color: AppColors.of(context).border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                          borderSide:
                              const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  PkButton(
                    label: isSaving ? 'Processing...' : 'Add Funds',
                    icon: Icons.add_rounded,
                    isLoading: isSaving,
                    onPressed: isSaving
                        ? null
                        : () async {
                            final amt =
                                double.tryParse(amountCtrl.text.trim());
                            if (amt == null || amt <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Enter a valid amount')));
                              return;
                            }
                            setSheet(() => isSaving = true);

                            // Use payment service abstraction
                            // Mock now → Simpaisa later (single line change)
                            final paymentService = getPaymentService();
                            PaymentInitResult initResult;
                            try {
                              initResult = await paymentService.initiateTopUp(
                                amount:    amt,
                                userEmail: ApiService.currentUser?.email ?? '',
                              );
                            } catch (e, st) {
                              ErrorUtils.logError('WalletScreen.initiateTopUp', e, st);
                              setSheet(() => isSaving = false);
                              if (!mounted) return;
                              ErrorUtils.showErrorSnack(context, ErrorUtils.friendlyMessage(e));
                              return;
                            }

                            setSheet(() => isSaving = false);
                            if (!mounted) return;

                            if (!initResult.success) {
                              ErrorUtils.showErrorSnack(
                                context,
                                initResult.error ?? 'Failed to initiate payment',
                              );
                              return;
                            }

                            // Close sheet, open payment WebView
                            Navigator.pop(ctx);
                            final paid = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentWebViewScreen(
                                  paymentUrl:    initResult.paymentUrl!,
                                  transactionId: initResult.transactionId!,
                                  amount:        amt,
                                ),
                              ),
                            );

                            if (paid == true && mounted) {
                              HapticFeedback.heavyImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Rs. ${amt.toStringAsFixed(0)} added! 🎉'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _loadWallet();
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _WalletHeader(onBack: () => Navigator.pop(context)),

            // Body
            Expanded(
              child: _isLoading
                  ? const _WalletSkeleton()
                  : _error != null
                      ? _WalletError(
                          error: _error!, onRetry: _loadWallet)
                      : RefreshIndicator(
                          onRefresh: _loadWallet,
                          color: AppColors.primary,
                          child: SingleChildScrollView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 4),

                                // Balance card — spring entrance
                                ScaleTransition(
                                  scale: _balanceScale,
                                  child: FadeTransition(
                                    opacity: _balanceFade,
                                    child: _BalanceCard(
                                      balance: _balance,
                                      onTopUp: _showTopUpSheet,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // Transactions
                                Row(children: [
                                  Text('Transaction History',
                                      style: AppTextStyles.titleLg.copyWith(
                                          color: AppColors.of(context)
                                              .textPrimary)),
                                ]),
                                const SizedBox(height: 14),

                                _transactions.isEmpty
                                    ? _EmptyTransactions()
                                    : Column(
                                        children: [
                                          for (int i = 0;
                                              i < _transactions.length;
                                              i++)
                                            SpringSlideIn(
                                              delay: Duration(
                                                  milliseconds: 40 * i),
                                              child: _TransactionTile(
                                                  tx: _transactions[i]),
                                            ),
                                        ],
                                      ),

                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _WalletHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _WalletHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.of(context).bgElevated,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border:
                  Border.all(color: AppColors.of(context).border),
            ),
            child: Icon(Icons.arrow_back_ios_rounded,
                size: 16,
                color: AppColors.of(context).textSecondary),
          ),
        ),
        const SizedBox(width: 14),
        Text('My Wallet',
            style: AppTextStyles.h2
                .copyWith(color: AppColors.of(context).textPrimary)),
      ]),
    );
  }
}

// ── Balance Card ─────────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final double balance;
  final VoidCallback onTopUp;
  const _BalanceCard({required this.balance, required this.onTopUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 16),
            ),
            const SizedBox(width: 10),
            Text('Available Balance',
                style: AppTextStyles.labelMd
                    .copyWith(color: Colors.white70)),
          ]),
          const SizedBox(height: 14),
          Text(
            'PKR ${balance.toStringAsFixed(2)}',
            style: AppTextStyles.display2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          // Top Up button
          GestureDetector(
            onTap: onTopUp,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Add Funds',
                      style: AppTextStyles.labelLg.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Tile ──────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final dynamic tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final type = tx['payment_type']?.toString() ?? 'online';
    final amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
    final status = tx['status']?.toString() ?? '';
    final isCredit = type == 'topup';
    final color = isCredit ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgCard,
        borderRadius:
            BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.of(context).border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMd),
          ),
          child: Icon(
            isCredit
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCredit ? 'Wallet Top Up' : 'Parking Payment',
                style: AppTextStyles.titleSm.copyWith(
                    color: AppColors.of(context).textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                status.toUpperCase(),
                style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.of(context).textHint),
              ),
            ],
          ),
        ),
        Text(
          '${isCredit ? '+' : '-'} PKR ${amount.toStringAsFixed(0)}',
          style: AppTextStyles.titleSm
              .copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────
class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: Column(
        children: [
          const SizedBox(height: 4),
          PkSkeleton(
            width: double.infinity,
            height: 200,
            borderRadius: AppConstants.radiusXl,
          ),
          const SizedBox(height: 28),
          ...List.generate(
              5,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PkSkeletonTransaction(), // ← correct widget for wallet
                  )),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _WalletError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _WalletError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.of(context).textHint),
          const SizedBox(height: 12),
          Text(error,
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.of(context).textHint),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          PkButton(
            label: 'Retry',
            onPressed: onRetry,
            variant: PkButtonVariant.ghost,
            fullWidth: false,
            size: PkButtonSize.medium,
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgElevated,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined,
            size: 44, color: AppColors.of(context).textHint),
        const SizedBox(height: 12),
        Text('No transactions yet',
            style: AppTextStyles.bodyMd
                .copyWith(color: AppColors.of(context).textHint)),
        const SizedBox(height: 4),
        Text('Your transaction history will appear here',
            style: AppTextStyles.bodySm
                .copyWith(color: AppColors.of(context).textDisabled)),
      ]),
    );
  }
}
