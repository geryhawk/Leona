import SwiftUI
import CloudKit

/// Wraps UICloudSharingController for sharing baby profiles via iMessage, email, etc.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let baby: Baby
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        share[CKShare.SystemFieldKey.title] = baby.displayName as CKRecordValue
        share[CKShare.SystemFieldKey.thumbnailImageData] = baby.profileImageData as CKRecordValue?

        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            // Share save failed — user will see the error in the controller
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Leona Baby Profile"
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onDismiss()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onDismiss()
        }
    }
}
