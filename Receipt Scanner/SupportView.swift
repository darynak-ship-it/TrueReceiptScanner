//
//  SupportView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI
import MessageUI

struct SupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var message = ""
    @State private var showMailComposer = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact Support")
                            .font(.largeTitle.bold())
                        Text("We're here to help! Send us your questions or feedback.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Contact Form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How can we help?")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.subheadline.bold())
                            
                            TextField("Brief description of your issue", text: $subject)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.subheadline.bold())
                            
                            TextEditor(text: $message)
                                .frame(minHeight: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .overlay(
                                    Group {
                                        if message.isEmpty {
                                            Text("Please describe your issue in detail...")
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 8)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        .padding(.horizontal)
                        
                        // Quick Help Topics
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Common Issues")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                HelpTopicButton(
                                    title: "Scanning Issues",
                                    description: "Receipt not scanning properly",
                                    action: { fillQuickMessage(topic: "Scanning Issues", message: "I'm having trouble scanning receipts. The OCR is not recognizing text properly.") }
                                )
                                
                                HelpTopicButton(
                                    title: "Data Export",
                                    description: "How to export my data",
                                    action: { fillQuickMessage(topic: "Data Export", message: "I would like to know how to export my receipt data.") }
                                )
                                
                                HelpTopicButton(
                                    title: "App Crashes",
                                    description: "App keeps crashing",
                                    action: { fillQuickMessage(topic: "App Crashes", message: "The app is crashing when I try to [describe what you were doing].") }
                                )
                                
                                HelpTopicButton(
                                    title: "Feature Request",
                                    description: "Suggest a new feature",
                                    action: { fillQuickMessage(topic: "Feature Request", message: "I would like to suggest a new feature: [describe your idea].") }
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Send Button
                        Button(action: sendEmail) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Send Email")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(subject.isEmpty || message.isEmpty)
                        
                        // Alternative Contact Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alternative Contact")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.accentColor)
                                    Text("Email: smthisbrewing@gmail.com")
                                        .font(.subheadline)
                                }
                                
                                Text("You can also email us directly if you prefer.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposerView(
                subject: subject,
                message: message,
                isShowing: $showMailComposer
            )
        }
        .alert("Email", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func fillQuickMessage(topic: String, message: String) {
        self.subject = topic
        self.message = message
    }
    
    private func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            alertMessage = "Mail services are not available. Please email us directly at smthisbrewing@gmail.com"
            showAlert = true
        }
    }
}

struct HelpTopicButton: View {
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let message: String
    @Binding var isShowing: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(["smthisbrewing@gmail.com"])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(message, isHTML: false)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isShowing = false
        }
    }
}

#Preview {
    SupportView()
}
