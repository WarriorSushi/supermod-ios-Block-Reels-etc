import SwiftUI

/// Evidence is presented with its intervention and limits; none is a Supermod outcome claim.
struct ResearchCard: View {
    enum Kind { case attention, connection }
    let kind: Kind
    @State private var revealed = false
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    private var attention: Bool { kind == .attention }
    var body: some View {
        VStack(spacing: availableHeight < 550 ? 12 : 18) {
            Text("A LITTLE PERSPECTIVE").font(.system(size: 10,weight: .bold)).tracking(2).foregroundStyle(Palette.muted)
            Heading(title: attention ? "Make room for\nyour attention." : "Less scrolling.\nStill connected.",centered: true)
            ZStack {
                Circle().fill(attention ? Color(hex: 0xDCE8D4) : Color(hex: 0xF6D8D4)).frame(width: 230,height: 230)
                if attention {
                    ForEach(0..<8) { index in
                        Capsule().fill(Palette.forest.opacity(0.18 + Double(index) * 0.09))
                            .frame(width: 12,height: revealed ? 45 + CGFloat(index % 4) * 18 : 12)
                            .offset(y: -65).rotationEffect(.degrees(Double(index) * 45))
                    }
                    Image(systemName: "eye").font(.system(size: 42,weight: .light)).foregroundStyle(Palette.forest)
                } else {
                    ForEach(0..<3) { index in
                        Image(["preview-nia","preview-sami","preview-mika"][index]).resizable().scaledToFill()
                            .frame(width: 83,height: 83).clipShape(Circle()).overlay(Circle().stroke(Palette.canvas,lineWidth: 4))
                            .offset(x: CGFloat(index - 1) * 62,y: index == 1 ? -28 : 24)
                            .scaleEffect(revealed ? 1 : 0.5)
                    }
                }
            }.frame(width: 240,height: 240)
                .scaleEffect(min(1,max(0.38,(availableHeight - 390) / 240)))
                .frame(height: min(240,max(90,availableHeight - 390))).accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline,spacing: 9) {
                Text(attention ? "2 weeks" : "3 weeks").font(.system(size: 38,weight: .bold)).tracking(-1.5)
                Text(attention ? "without mobile internet" : "with daily limits").font(.caption).foregroundStyle(Palette.muted)
            }
            Text(attention
                 ? "A randomized study found improved sustained attention after participants blocked mobile internet on their phones."
                 : "In a randomized study of 143 students, limiting three social apps to 10 minutes each per day reduced loneliness compared with usual use.")
                .font(.subheadline).multilineTextAlignment(.center).fixedSize(horizontal: false,vertical: true)
            VStack(spacing: 8) {
                Text(attention
                     ? "This tested blocking all mobile internet—not Supermod’s selective filters. Only 119 of 467 participants met the study’s compliance threshold."
                     : "A short study of college students, not a test of Supermod. Individual experiences vary.")
                    .font(.caption2).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                Link(attention ? "Read the research · PNAS Nexus, 2025 ↗" : "Read the research · Hunt et al., 2018 ↗",
                     destination: URL(string: attention ? "https://pmc.ncbi.nlm.nih.gov/articles/PMC11834938/" : "https://doi.org/10.1521/jscp.2018.37.10.751")!)
                    .font(.caption.weight(.semibold)).frame(minHeight: 44)
            }
        }.frame(maxWidth: .infinity)
            .onAppear { withAnimation(reduceMotion ? nil : .spring(duration: 0.8,bounce: 0.2)) { revealed = true } }
    }
}

struct AttentionScene: View {
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var thrown = false
    @State private var cleared = false
    var body: some View {
        VStack(spacing: 22) {
            Heading(title: "Keep the good.\nBin the noise.", detail: "Less Reels. Fewer ads. More room for you.", centered: true)
            ZStack {
                ForEach(0..<3) { index in
                    VStack(spacing: 12) {
                        Image(systemName: ["play.rectangle.fill", "megaphone.fill", "sparkles"][index]).font(.system(size: 28))
                        Text(["Reels", "Ads", "For you"][index]).font(.caption.bold())
                    }.foregroundStyle(PaywallPalette.plum).frame(width: 82, height: 102)
                        .background(PaywallPalette.blush, in: RoundedRectangle(cornerRadius: 19))
                        .rotationEffect(.degrees(thrown ? Double(index - 1) * 85 : Double(index - 1) * 12))
                        .scaleEffect(thrown ? 0.18 : 1)
                        .offset(x: thrown ? 0 : Double(index - 1) * 98, y: thrown ? 75 : -80)
                        .opacity(thrown ? 0 : 1)
                        .animation(reduceMotion ? nil : .easeIn(duration: 0.75).delay(Double(index) * 0.2), value: thrown)
                }
                Image(systemName: "trash.fill").font(.system(size: 100, weight: .light))
                    .foregroundStyle(PaywallPalette.plum).offset(y: 80)
                    .scaleEffect(cleared ? 0.15 : 1).opacity(cleared ? 0 : 1)
                AttentionDots(progress: cleared ? 1 : 0)
                    .opacity(cleared ? 1 : 0).scaleEffect(cleared ? 1 : 0.25)
            }.frame(maxWidth: 330).frame(height: 340).accessibilityHidden(true)
        }.frame(maxWidth: .infinity)
            .task {
                if reduceMotion { thrown = true; cleared = true; return }
                do {
                    try await Task.sleep(for: .milliseconds(850)); thrown = true
                    try await Task.sleep(for: .seconds(1.6))
                    withAnimation(.spring(response: 1.4, dampingFraction: 0.85)) { cleared = true }
                } catch { return }
            }
    }
}

private struct AttentionDots: View, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for index in 0..<128 {
                let seed = Double((index * 79) % 131) / 131
                let angle = Double(index) * 2.399963
                let startRadius = sqrt(Double(index) / 128) * 140
                let endRadius = 105 + seed * 32
                let radius = startRadius + (endRadius - startRadius) * progress
                let theta = angle + progress * (0.28 + seed * 0.35)
                let diameter = 3 + seed * 5
                let point = CGPoint(x: center.x + cos(theta) * radius, y: center.y + sin(theta) * radius)
                let dot = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: dot), with: .color(Color(hex: index % 3 == 0 ? 0xDDA3B0 : 0xEEC7BE).opacity(0.6 + seed * 0.4)))
            }
            let symbol = context.resolve(Text(Image(systemName: "sparkle")).font(.system(size: 38, weight: .light)).foregroundColor(Color(hex: 0xA76A7D)))
            context.opacity = max(0, progress)
            context.draw(symbol, at: center)
        }
    }
}

struct WellbeingStudyScene: View {
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var after = false
    @State private var details = false
    private var heroSize: Double { min(310, max(170, availableHeight - 320)) }
    var body: some View {
        VStack(spacing: availableHeight < 550 ? 12 : 18) {
            Heading(title: "Less scrolling.\nLess stress.", detail: "Students who cut phone time felt less stressed after 3 weeks.", centered: true)
            ZStack {
                ForEach(0..<3) { index in
                    CalmLoop(tension: after ? 0 : 1)
                        .stroke(index == 0 ? Color.black : PaywallPalette.outline,
                                style: StrokeStyle(lineWidth: index == 0 ? 4 : 2, lineCap: .round, lineJoin: .round))
                        .rotationEffect(.degrees(after ? 0 : Double(index * 34)))
                        .scaleEffect(after ? 1 + Double(index) * 0.05 : 0.94 + Double(index) * 0.04)
                        .opacity(after && index > 0 ? 0.18 : 1)
                }
                VStack(spacing: 2) {
                    Text("16%").font(.system(size: 69, weight: .bold)).tracking(-3)
                    Text("less stress").font(.title3.weight(.medium))
                }.scaleEffect(after ? 1 : 0.8).opacity(after ? 1 : 0)
            }
            .frame(width: heroSize, height: heroSize)
            .padding(.vertical, availableHeight < 550 ? 6 : 15).accessibilityElement(children: .ignore)
            .accessibilityLabel("16 percent less stress after three weeks in the students who cut phone use")
            Text("In one study, students cut phone use to 2 hours a day.")
                .font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            StudySourceButton { details = true }
        }.frame(maxWidth: .infinity)
            .task {
                if reduceMotion { after = true; return }
                do { try await Task.sleep(for: .milliseconds(850)) } catch { return }
                withAnimation(.easeInOut(duration: 1.6)) { after = true }
            }
            .sheet(isPresented: $details) { StudyDetails(attention: false) }
    }
}

private struct CalmLoop: Shape {
    var tension: Double
    var animatableData: Double {
        get { tension }
        set { tension = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0...180 {
            let theta = Double(index) / 180 * .pi * 2
            let radius = min(rect.width, rect.height) * (0.42 + tension * (0.065 * sin(theta * 7) + 0.055 * cos(theta * 11)))
            let p = CGPoint(x: rect.midX + cos(theta) * radius, y: rect.midY + sin(theta) * radius)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

struct StudySourceButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            HStack(spacing: 13) {
                Image(systemName: "book.closed").font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("See the study").font(.subheadline.weight(.semibold))
                    Text("Read what the research found").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer(); Image(systemName: "arrow.up.right")
            }.padding(15).foregroundStyle(Palette.ink)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(PaywallPalette.outline.opacity(0.5), lineWidth: 1))
        }.buttonStyle(PressStyle())
    }
}

private struct MoodFace: Shape {
    var smile: Double
    var animatableData: Double {
        get { smile }
        set { smile = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for x in [0.27, 0.73] {
            path.move(to: CGPoint(x: rect.width * x, y: rect.height * 0.26))
            path.addLine(to: CGPoint(x: rect.width * x, y: rect.height * 0.34))
        }
        path.move(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.62))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.62),
                         control: CGPoint(x: rect.midX, y: rect.height * (0.62 + 0.52 * smile)))
        return path
    }
}

struct SleepStudyScene: View {
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var settled = false
    @State private var details = false
    private var heroSize: Double { min(330, max(190, availableHeight - 275)) }

    var body: some View {
        VStack(spacing: 18) {
            Heading(title: "Less phone time.\nBetter sleep.", detail: "In one study, students slept better.", centered: true)
            ZStack {
                Circle().fill(.black)
                ForEach(0..<3) { index in
                    Image(systemName: "cloud.fill")
                        .font(.system(size: heroSize * [0.30, 0.38, 0.25][index]))
                        .foregroundStyle(Color(white: [0.24, 0.33, 0.19][index]))
                        .offset(x: heroSize * (settled ? [-0.22, 0.17, -0.02][index] : [-0.38, 0.35, -0.20][index]),
                                y: heroSize * [-0.12, 0.15, 0.29][index])
                        .animation(reduceMotion ? nil : .easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(Double(index) * 0.25), value: settled)
                }
                ForEach(0..<8) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: CGFloat(9 + index % 3 * 5)))
                        .foregroundStyle(PaywallPalette.blush)
                        .offset(x: cos(Double(index) * .pi / 4) * heroSize * 0.37,
                                y: sin(Double(index) * .pi / 4) * heroSize * 0.37)
                        .scaleEffect(settled ? 1 : 0.15).opacity(settled ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.65).delay(Double(index) * 0.1), value: settled)
                }
                Image(systemName: "moon.fill")
                    .font(.system(size: heroSize * 0.42, weight: .light))
                    .foregroundStyle(Color(hex: 0xFFF2D7))
                    .rotationEffect(.degrees(settled ? -12 : 35))
                    .scaleEffect(settled ? 1 : 0.45)
                    .offset(y: settled ? 0 : 45)
            }
            .frame(width: heroSize, height: heroSize).padding(.vertical, 12)
            .accessibilityHidden(true)
            Text("After 3 weeks of less phone time")
                .font(.headline).multilineTextAlignment(.center)
            StudySourceButton { details = true }
        }.frame(maxWidth: .infinity)
            .task {
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(300)) }
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 1.6, dampingFraction: 0.72)) { settled = true }
            }
            .sheet(isPresented: $details) { StudyDetails(attention: false) }
    }
}

struct FocusStudyScene: View {
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var clear = false
    @State private var details = false
    private var heroSize: Double { min(330, max(200, availableHeight - 280)) }

    var body: some View {
        VStack(spacing: 18) {
            Heading(title: "Less noise.\nMore focus.", detail: "In one study, people could focus better.", centered: true)
            ZStack {
                RoundedRectangle(cornerRadius: 65).fill(PaywallPalette.selection)
                ForEach(0..<12) { index in
                    Image(systemName: ["heart.fill", "play.fill", "bell.fill"][index % 3])
                        .font(.system(size: 16 + Double(index % 3) * 6))
                        .foregroundStyle(PaywallPalette.outline)
                        .offset(x: cos(Double(index) * 2.4) * heroSize * (clear ? 0.7 : 0.32),
                                y: sin(Double(index) * 2.4) * heroSize * (clear ? 0.7 : 0.32))
                        .opacity(clear ? 0 : 0.75).scaleEffect(clear ? 0.3 : 1)
                }
                RoundedRectangle(cornerRadius: 32)
                    .trim(from: 0, to: clear ? 1 : 0.05)
                    .stroke(PaywallPalette.plum, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .padding(heroSize * 0.14)
                Text("One\nthing.").font(.system(size: heroSize * 0.16, weight: .bold))
                    .tracking(-2).multilineTextAlignment(.center)
                    .foregroundStyle(PaywallPalette.plum)
                    .blur(radius: clear ? 0 : 9).opacity(clear ? 1 : 0.3)
                    .scaleEffect(clear ? 1 : 0.75)
            }
            .frame(width: heroSize, height: heroSize).padding(.vertical, 12).accessibilityHidden(true)
            Text("2 weeks with phone internet off")
                .font(.headline).multilineTextAlignment(.center)
            StudySourceButton { details = true }
        }.frame(maxWidth: .infinity)
            .task {
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(600)) }
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.8)) { clear = true }
            }
            .sheet(isPresented: $details) { StudyDetails(attention: true) }
    }
}

private struct StudyDetails: View {
    let attention: Bool
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(attention ? "Two weeks offline on mobile" : "Three weeks with less phone time").font(.title2.bold())
                    Text(attention
                         ? "A randomized trial enrolled 467 adults. Participants were asked to block all mobile internet for two weeks. Calls, texts and internet on other devices remained available. Attention was measured with a computerized task. Only 119 participants met the prespecified adherence threshold."
                         : "Researchers randomly assigned 111 students to a three-week phone-use limit of two hours a day or usual use. Table 2 reports these group averages: well-being rose from 56.6 to 64.4 out of 100 with less phone use, versus 57.8 to 58.3 with usual use. Sleep difficulty fell from 8.8 to 7.2 out of 28, versus 9.3 to 9.8 with usual use; lower is better. Stress fell by 16% from the starting level in the reduction group. The 16% figure is the relative before/after change in that group, not its difference from the control group. The calming line is an illustration, not a health measurement. The usual-use group had no significant stress change. These are group averages, not personal forecasts. Well-being uses WHO-5 scores multiplied by four; sleep uses the Insomnia Severity Index. Only 24 of 58 in the reduction group strictly met the limit. Phone use rose again after the intervention.")
                    Text("These are results of the study’s intervention. Individual outcomes vary; Supermod has not been tested in these trials.").foregroundStyle(Palette.muted)
                    Link("Read the original study ↗", destination: URL(string: attention ? "https://doi.org/10.1093/pnasnexus/pgaf017" : "https://doi.org/10.1186/s12916-025-03944-z")!)
                }.padding(24)
            }
            .navigationTitle("Research").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { Haptics.selection(); dismiss() } } }
        }.tint(PaywallPalette.accent)
    }
}
