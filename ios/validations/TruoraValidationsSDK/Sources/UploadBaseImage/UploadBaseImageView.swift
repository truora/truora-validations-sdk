//
//  UploadBaseImageView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import SwiftUI
import UIKit

class UploadBaseImageViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isShowingImagePicker = false
    @Published var selectedImage: UIImage?

    weak var presenter: UploadBaseImageViewToPresenter?

    func onAppear() {
        presenter?.viewDidLoad()
    }

    func selectImage() {
        presenter?.selectImageTapped()
    }

    func upload() {
        presenter?.uploadTapped()
    }

    func cancel() {
        presenter?.cancelTapped()
    }

    func handleImageSelection(_ image: UIImage) {
        selectedImage = image
        presenter?.imageSelected(image)
    }
}

extension UploadBaseImageViewModel: UploadBaseImagePresenterToView {
    func showLoading() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }

    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }

    func showImagePicker() {
        DispatchQueue.main.async {
            self.isShowingImagePicker = true
        }
    }

    func displaySelectedImage(_ image: UIImage) {
        DispatchQueue.main.async {
            self.selectedImage = image
        }
    }
}

struct UploadBaseImageView: View {
    @ObservedObject var viewModel: UploadBaseImageViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Spacer()
                    .frame(height: 40)

                if let selectedImage = viewModel.selectedImage {
                    SwiftUI.Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(width: 300, height: 200)
                        .cornerRadius(12)
                        .overlay(
                            Text("No image selected")
                                .foregroundColor(.gray)
                        )
                }

                Button(action: {
                    viewModel.selectImage()
                }, label: {
                    Text("Select ID Photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 250, height: 50)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                })
                .disabled(viewModel.isLoading)

                Spacer()

                Button(action: {
                    viewModel.upload()
                }, label: {
                    Text("Upload & Continue")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 250, height: 50)
                        .background(viewModel.selectedImage != nil ? Color.blue : Color.gray)
                        .cornerRadius(12)
                })
                .disabled(viewModel.selectedImage == nil || viewModel.isLoading)
                .padding(.bottom, 30)
            }
            .padding()

            if viewModel.isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)

                LoadingIndicatorView(isAnimating: .constant(true), style: .large, color: .systemBlue)
                    .scaleEffect(1.5)
            }
        }
        .navigationBarTitle("Upload ID Photo", displayMode: .inline)
        .navigationBarItems(leading: Button("Cancel") {
            viewModel.cancel()
        })
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: viewModel.errorMessage.map { Text($0) },
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $viewModel.isShowingImagePicker) {
            ImagePicker { image in
                viewModel.handleImageSelection(image)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void

        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                print("⚠️ ImagePicker: Failed to extract image from picker")
                picker.dismiss(animated: true)
                return
            }
            onImageSelected(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

private struct LoadingIndicatorView: UIViewRepresentable {
    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style
    let color: UIColor

    func makeUIView(context _: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: style)
        indicator.color = color
        return indicator
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context _: Context) {
        if isAnimating {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}
