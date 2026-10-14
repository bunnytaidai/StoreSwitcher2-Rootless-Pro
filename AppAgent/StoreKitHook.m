#import "StoreKitHook.h"
#import "AgentPacketManager.h"
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

static void (*orig_addPayment)(id, SEL, SKPayment *);
static void my_addPayment(id self, SEL _cmd, SKPayment *payment) {
    if (payment) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"action"] = @"addPayment";
        dict[@"productId"] = payment.productIdentifier ?: @"";
        dict[@"quantity"] = @(payment.quantity);
        if (payment.applicationUsername) dict[@"appUsername"] = payment.applicationUsername;
        dict[@"simulatesAskToBuyInSandbox"] = @(payment.simulatesAskToBuyInSandbox);

        AgentPacket *packet = [[AgentPacket alloc] init];
        packet.type = AgentPacketTypeIAP;
        packet.title = [NSString stringWithFormat:@"[IAP Buy] %@", payment.productIdentifier];
        packet.payload = dict;
        [[AgentPacketManager sharedManager] recordPacket:packet];
    }
    if (orig_addPayment) {
        orig_addPayment(self, _cmd, payment);
    }
}

static void (*orig_addTransactionObserver)(id, SEL, id<SKPaymentTransactionObserver>);
static void my_addTransactionObserver(id self, SEL _cmd, id<SKPaymentTransactionObserver> observer) {
    if (observer) {
        Class obsClass = [observer class];
        SEL updatedSel = @selector(paymentQueue:updatedTransactions:);
        Method m = class_getInstanceMethod(obsClass, updatedSel);
        if (m) {
            // Swizzle paymentQueue:updatedTransactions:
            __block void (*orig_updatedTrans)(id, SEL, SKPaymentQueue *, NSArray *) = NULL;
            IMP newImp = imp_implementationWithBlock(^(id target, SKPaymentQueue *queue, NSArray<SKPaymentTransaction *> *transactions) {
                for (SKPaymentTransaction *trans in transactions) {
                    NSMutableDictionary *tDict = [NSMutableDictionary dictionary];
                    tDict[@"productId"] = trans.payment.productIdentifier ?: @"";
                    tDict[@"state"] = @(trans.transactionState);
                    tDict[@"transactionId"] = trans.transactionIdentifier ?: @"";
                    if (trans.transactionDate) tDict[@"date"] = [trans.transactionDate description];
                    if (trans.error) tDict[@"error"] = trans.error.localizedDescription;

                    // Lấy Base64 Receipt
                    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                    if (receiptURL && [[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
                        NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
                        if (receiptData) {
                            tDict[@"receiptBase64"] = [receiptData base64EncodedStringWithOptions:0];
                        }
                    }

                    AgentPacket *packet = [[AgentPacket alloc] init];
                    packet.type = AgentPacketTypeIAP;
                    NSString *stateStr = @"Unknown";
                    switch (trans.transactionState) {
                        case SKPaymentTransactionStatePurchasing: stateStr = @"Purchasing"; break;
                        case SKPaymentTransactionStatePurchased: stateStr = @"Purchased (Thành công)"; break;
                        case SKPaymentTransactionStateFailed: stateStr = @"Failed (Thất bại)"; break;
                        case SKPaymentTransactionStateRestored: stateStr = @"Restored (Khôi phục)"; break;
                        case SKPaymentTransactionStateDeferred: stateStr = @"Deferred (Chờ duyệt)"; break;
                    }
                    packet.title = [NSString stringWithFormat:@"[IAP State: %@] %@", stateStr, trans.payment.productIdentifier];
                    packet.payload = tDict;
                    packet.statusCode = trans.transactionState;
                    [[AgentPacketManager sharedManager] recordPacket:packet];
                }

                if (orig_updatedTrans) {
                    orig_updatedTrans(target, updatedSel, queue, transactions);
                }
            });

            orig_updatedTrans = (void (*)(id, SEL, SKPaymentQueue *, NSArray *))method_setImplementation(m, newImp);
        }
    }

    if (orig_addTransactionObserver) {
        orig_addTransactionObserver(self, _cmd, observer);
    }
}

@implementation StoreKitHook

+ (void)installHook {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class queueClass = objc_getClass("SKPaymentQueue");
        if (queueClass) {
            Method mAdd = class_getInstanceMethod(queueClass, @selector(addPayment:));
            if (mAdd) {
                orig_addPayment = (void (*)(id, SEL, SKPayment *))method_setImplementation(mAdd, (IMP)my_addPayment);
            }

            Method mObs = class_getInstanceMethod(queueClass, @selector(addTransactionObserver:));
            if (mObs) {
                orig_addTransactionObserver = (void (*)(id, SEL, id<SKPaymentTransactionObserver>))method_setImplementation(mObs, (IMP)my_addTransactionObserver);
            }
        }
    });
}

@end
