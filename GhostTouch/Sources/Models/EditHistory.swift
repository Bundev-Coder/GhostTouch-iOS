import UIKit

/// Bản ghi lịch sử chỉnh sửa hỗ trợ Undo / Redo mượt mà
struct EditStep: Identifiable {
    let id = UUID()
    let timestamp: Date = Date()
    let image: UIImage
    let description: String
}

class EditHistoryManager: ObservableObject {
    @Published var undoStack: [EditStep] = []
    @Published var redoStack: [EditStep] = []
    
    var canUndo: Bool {
        return undoStack.count > 1
    }
    
    var canRedo: Bool {
        return !redoStack.isEmpty
    }
    
    func reset(initialImage: UIImage) {
        undoStack = [EditStep(image: initialImage, description: "Ảnh ban đầu")]
        redoStack.removeAll()
    }
    
    func push(newImage: UIImage, actionName: String) {
        let step = EditStep(image: newImage, description: actionName)
        undoStack.append(step)
        // Giới hạn 15 bước để tối ưu RAM iPhone
        if undoStack.count > 15 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }
    
    func undo() -> UIImage? {
        guard canUndo else { return nil }
        let current = undoStack.removeLast()
        redoStack.append(current)
        return undoStack.last?.image
    }
    
    func redo() -> UIImage? {
        guard canRedo else { return nil }
        let next = redoStack.removeLast()
        undoStack.append(next)
        return next.image
    }
    
    var currentImage: UIImage? {
        return undoStack.last?.image
    }
    
    var initialImage: UIImage? {
        return undoStack.first?.image
    }
}
