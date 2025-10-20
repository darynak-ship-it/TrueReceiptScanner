//
//  OnboardingFlowView.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import SwiftUI

enum OnboardingFinishAction {
    case scanNow
    case useSample
}

struct OnboardingFlowView: View {
    let onFinish: (OnboardingFinishAction) -> Void
    let onRequestScan: () -> Void
    let onRequestSample: () -> Void

    @State private var step: Int = 1 // 1...4

    var body: some View {
        GeometryReader { proxy in
            let bottomHeight = proxy.size.height * 0.5
            VStack(spacing: 0) {
                // Top content area with Back and Image
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        // Reserve space for Back button height
                        Spacer(minLength: 44)
                        ScrollView(showsIndicators: false) {
                            imageView
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 520)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                                .padding(.bottom, 12)
                        }
                    }

                    if step > 1 {
                        Button(action: { step = max(1, step - 1) }) {
                            Text("Back")
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: proxy.size.height - bottomHeight)

                // Bottom half gray pad
                VStack(alignment: .leading, spacing: 12) {
                    if step <= 3 {
                        HStack { Spacer() }
                        .overlay(
                            ProgressDots(current: step)
                        )
                        .padding(.top, 8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(header)
                            .font(.title.bold())
                            .multilineTextAlignment(.leading)
                        if let sub = subtext {
                            Text(sub)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(spacing: 12) {
                        primaryButton
                        if step == 4 {
                            secondaryButton
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: bottomHeight)
                .background(Color(UIColor.systemGray6))
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var imageView: Image {
        switch step {
        case 1: return Image("Image 1")
        case 2: return Image("Image 2")
        case 3: return Image("Image 3")
        default: return Image("Image 4")
        }
    }

    private var header: String {
        switch step {
        case 1: return "Never Lose a Receipt"
        case 2: return "Know Your Deductions"
        case 3: return "Reports in Seconds"
        default: return "Ready to Scan Your First Receipt?"
        }
    }

    private var subtext: String? {
        switch step {
        case 1:
            return "Snap and save your receipts on-the-go."
        case 2:
            return "Sort and categorize expenses to create reimbursement forms or fill in tax."
        case 3:
            return "Create, export and send PDF, CSV or Excel reports."
        default:
            return nil
        }
    }

    private var primaryButton: some View {
        Button(action: {
            if step < 4 {
                step += 1
            } else {
                onFinish(.scanNow)
                onRequestScan()
            }
        }) {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }

    private var secondaryButton: some View {
        Button(action: {
            onFinish(.useSample)
            onRequestSample()
        }) {
            Text("Skip, I don’t have a receipt right now")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.clear)
                .foregroundColor(.accentColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

private struct ProgressDots: View {
    let current: Int // 1..3
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1..<4) { idx in
                Circle()
                    .fill(idx == current ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    OnboardingFlowView(onFinish: { _ in }, onRequestScan: {}, onRequestSample: {})
}


