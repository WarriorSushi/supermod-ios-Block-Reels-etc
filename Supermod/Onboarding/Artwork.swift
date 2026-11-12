import SwiftUI
import AVFoundation

struct PassageArtwork: View {
    var variant: Int = 0
    var showsMascot = true
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(hex: 0xFFF0E1), Color(hex: 0xFFA497)], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach(0..<10) { index in
                    Ellipse()
                        .strokeBorder(Color(hex: 0xA93149).opacity(0.11 + Double(index % 3) * 0.035), lineWidth: 1)
                        .frame(width: proxy.size.width * (0.35 + Double(index) * 0.13),
                               height: proxy.size.width * (0.16 + Double(index) * 0.073))
                        .rotationEffect(.degrees(-25 + Double(variant * 9)))
                        .offset(x: proxy.size.width * 0.06, y: proxy.size.height * 0.05)
                }
                if showsMascot {
                    BrandMascot(size: min(proxy.size.width, proxy.size.height) * 0.63)
                        .shadow(color: Color(hex: 0x741E3B).opacity(0.22), radius: 14, x: 0, y: 10)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 29))
        .accessibilityHidden(true)
    }
}

enum DemoPanel: String, CaseIterable {
    case feed = "Feed", messages = "Messages", keyboard = "Chat", profile = "Profile"
}

struct SegmentedDemoControl: View {
    @Binding var filtered: Bool
    var originalTitle = "Original"
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @Namespace private var selection
    var body: some View {
        HStack(spacing: 0) {
            segment(originalTitle, value: false)
            segment("Supermod", value: true)
        }
        .padding(3).background(Palette.surface, in: Capsule())
        .frame(width: 224)
    }
    private func segment(_ title: String, value: Bool) -> some View {
        Button { Haptics.selection();
            withAnimation(reduceMotion ? nil : .onboardingSpring) { filtered = value }
        } label: {
            Text(title).font(.system(size: 12, weight: filtered == value ? .semibold : .regular))
                .foregroundStyle(filtered == value ? Palette.ink : Palette.muted)
                .frame(maxWidth: .infinity, minHeight: 31)
                .background {
                    if filtered == value {
                        Capsule().fill(Palette.canvas).shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            .matchedGeometryEffect(id: "segment", in: selection)
                    }
                }
        }.buttonStyle(.plain).accessibilityAddTraits(filtered == value ? .isSelected : [])
    }
}

/// One full-size screen coordinate system. The frame and every pixel of its content
/// scale together, preserving actual iPhone proportions at every presentation size.
private struct DemoPhoneWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 1000 }
extension EnvironmentValues {
    var demoPhoneWidth: CGFloat {
        get { self[DemoPhoneWidthKey.self] }
        set { self[DemoPhoneWidthKey.self] = newValue }
    }
}

struct PhoneDemo: View {
    let hidden: Set<Mod>
    var panel: DemoPanel = .feed
    var width: CGFloat = 232
    var showsAd = false
    var youtube = false
    var facebook = false
    var feedOffset: CGFloat = 0
    var removing: Mod?
    var removalProgress: Double = 0
    var frameless = false
    var spotlightsReels = false
    @Environment(\.demoPhoneWidth) private var maximumWidth
    private var renderedWidth: CGFloat { min(width, maximumWidth) }
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var holdsReelsSlot = false
    @State private var magnified = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 62).fill(Color.black)
                .overlay { RoundedRectangle(cornerRadius: 62).strokeBorder(Color(hex: 0x777975), lineWidth: 3) }
            screen
                .frame(width: 390, height: 844)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 52))
            Capsule().fill(.black).frame(width: 112, height: 32).offset(y: -397)
            Capsule().fill(.black).frame(width: 132, height: 5).offset(y: 407)
        }
        .frame(width: 410, height: 864)
        .overlay {
            if let removing {
                let top = removing == .stories ? 115.0 : removing == .reels || removing == .explore ? 770.0 : hidden.contains(.stories) ? 115.0 : 222.0
                let height = removing == .stories ? 105.0 : removing == .reels || removing == .explore ? 50.0 : min(486, 765 - top)
                FeatureRemovalPoof(progress: removalProgress)
                    .frame(width: 384, height: height)
                    .position(x: 205, y: top + height / 2)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .overlay(alignment: .leading) {
            VStack(spacing: 19) {
                Capsule().fill(Color(hex: 0x565853)).frame(width: 3, height: 26)
                Capsule().fill(Color(hex: 0x565853)).frame(width: 3, height: 53)
                Capsule().fill(Color(hex: 0x565853)).frame(width: 3, height: 53)
            }.offset(x: -2, y: -180)
        }
        .overlay(alignment: .bottom) {
            if spotlightsReels {
                navigation
                    .frame(width: 390)
                    .padding(.vertical, 8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: 0xE8B4BF), lineWidth: 2) }
                    .shadow(color: Color(hex: 0x7B3E54).opacity(0.18), radius: 12, y: 6)
                    .scaleEffect(magnified ? 1.38 : 1)
                    .offset(y: magnified ? -40 : -22)
                    .opacity(magnified ? 1 : 0)
            }
        }
        .scaleEffect(renderedWidth / 410)
        .frame(width: renderedWidth, height: renderedWidth * 864 / 410)
        .shadow(color: .black.opacity(frameless ? 0 : 0.17), radius: 12, x: 0, y: 9)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .medium)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample \(youtube ? "YouTube" : "Instagram") \(panel.rawValue.lowercased())")
        .accessibilityValue("\(showsAd && !hidden.contains(.sponsored) ? "Sponsored coffee post visible. " : "")\(hidden.isEmpty ? "All sample features visible" : "Hidden: " + Mod.allCases.filter(hidden.contains).map(\.title).joined(separator: ", "))")
        .accessibilityIdentifier("sample.phone")
        .task {
            guard spotlightsReels else { return }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(950)) }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.85, dampingFraction: 0.8)) { magnified = true }
        }
        .task(id: hidden.contains(.reels)) {
            guard spotlightsReels else { return }
            if hidden.contains(.reels) {
                if !reduceMotion {
                    do { try await Task.sleep(for: .milliseconds(480)) } catch { return }
                }
                withAnimation(reduceMotion ? nil : .onboardingSpring) { holdsReelsSlot = false }
            } else {
                holdsReelsSlot = true
            }
        }
    }

    var screen: some View {
        VStack(spacing: 0) {
            HStack {
                Text("9:41").font(.system(size: 15, weight: .semibold)).padding(.leading, 25)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "cellularbars"); Image(systemName: "wifi"); Image(systemName: "battery.100percent")
                }.font(.system(size: 14, weight: .semibold)).padding(.trailing, 23)
            }.frame(height: 55)
            if youtube { youtubeFeed }
            else {
                switch panel {
                case .feed: instagramFeed
                case .messages: inbox
                case .keyboard: conversation
                case .profile: profile
                }
            }
            Spacer(minLength: 0)
            if panel != .keyboard || youtube { navigation }
            Color.clear.frame(height: 22)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.88), value: hidden)
    }

    private var instagramFeed: some View {
        VStack(spacing: 0) {
            HStack(spacing: 19) {
                Text(facebook ? "facebook" : "Instagram")
                    .font(facebook ? .system(size: 31, weight: .bold) : .custom("SnellRoundhand-Bold", size: 31))
                    .foregroundStyle(facebook ? Color.blue : Color.black)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                Spacer()
                Image(systemName: "heart"); Image(systemName: "paperplane")
                    .overlay(alignment: .topTrailing) { Circle().fill(.red).frame(width: 7, height: 7).offset(x: 4, y: -2) }
            }.font(.system(size: 24)).padding(.horizontal, 15).frame(height: 50)
            if !hidden.contains(.stories) {
                HStack(spacing: 17) {
                    ForEach(0..<4) { i in
                        VStack(spacing: 5) {
                            avatar(i, size: 64)
                                .padding(4)
                                .overlay { Circle().stroke(LinearGradient(colors: [.yellow, .pink, .purple], startPoint: .bottomLeading, endPoint: .topTrailing), lineWidth: 2.5) }
                            Text(["Your story", "nia.outside", "mika.studio", "june.jpg"][i])
                                .font(.system(size: 11))
                        }
                    }
                }.padding(.vertical, 8)
                Divider()
            }
            if facebook && !hidden.contains(.reels) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reels").font(.system(size: 18, weight: .bold))
                    HStack(spacing: 8) {
                        photo("preview-coast", height: 175)
                        photo("preview-city", height: 175)
                    }
                }.padding(12).transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            if showsAd {
                GeometryReader { geometry in
                    switchPreviewPosts.frame(width: geometry.size.width)
                        .offset(y: -feedOffset)
                }.clipped()
            } else if hidden.contains(.feed) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle").font(.system(size: 44, weight: .ultraLight))
                    Text("You're all caught up").font(.system(size: 20, weight: .semibold))
                    Text("Your people are still one message away.").font(.system(size: 13)).foregroundStyle(.gray)
                }.frame(maxWidth: .infinity, minHeight: 430)
            } else {
                VStack(spacing: 0) {
                        postHeader(name: "nia.outside", subtitle: "Bali, Indonesia", avatarIndex: 0)
                        photo("preview-waterfall", height: 337)
                        postActions
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Liked by mika.studio and 248 others").font(.system(size: 12, weight: .semibold))
                            Text("nia.outside  Took the scenic route 🌿").font(.system(size: 12))
                            Text("View all 18 comments").foregroundStyle(.gray).font(.system(size: 12))
                            Text("2 HOURS AGO").foregroundStyle(.gray).font(.system(size: 9))
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13)
                    if !hidden.contains(.suggestions) {
                        HStack { Text("Suggested for you"); Spacer(); Text("See all").foregroundStyle(.blue) }
                            .font(.system(size: 12, weight: .semibold)).padding(14)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }.frame(maxHeight: .infinity, alignment: .top).clipped()
    }

    private var switchPreviewPosts: some View {
        VStack(spacing: 0) {
            friendPost("nia.outside", image: "preview-waterfall", avatarIndex: 0)
            if !hidden.contains(.sponsored) {
                VStack(spacing: 0) {
                    postHeader(name: "daybreak.store · AD", subtitle: "Sponsored", avatarIndex: 3)
                    photo("preview-coffee", height: 390)
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("UP TO 30% OFF").font(.system(size: 35, weight: .black))
                                Text("More stuff you didn’t need.").font(.system(size: 18))
                                Text("Shop now →").font(.system(size: 16, weight: .bold))
                            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(hex: 0xFFE4CE).opacity(0.94))
                        }
                    postActions
                }.transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            friendPost("june.jpg", image: "preview-coast", avatarIndex: 3)
            if !hidden.contains(.suggestions) {
                VStack(spacing: 0) {
                    postHeader(name: "mika.studio", subtitle: "Suggested for you", avatarIndex: 2)
                    photo("preview-camera", height: 390)
                    postActions
                }.transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            friendPost("sami", image: "preview-city", avatarIndex: 1)
            friendPost("nia.outside", image: "preview-waterfall", avatarIndex: 0)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func friendPost(_ name: String, image: String, avatarIndex: Int) -> some View {
        VStack(spacing: 0) {
            postHeader(name: name, subtitle: "Post from your friend", avatarIndex: avatarIndex)
            photo(image, height: 390)
            postActions
            Text("A good day, with good people.").font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 13).frame(height: 24)
        }
    }

    private var postActions: some View {
        HStack(spacing: 15) {
            if facebook {
                Label("Like", systemImage: "hand.thumbsup")
                Spacer(); Label("Comment", systemImage: "bubble")
                Spacer(); Label("Share", systemImage: "arrowshape.turn.up.right")
            } else {
                Image(systemName: "heart"); Image(systemName: "bubble"); Image(systemName: "paperplane")
                Spacer(); Image(systemName: "bookmark")
            }
        }.font(.system(size: facebook ? 15 : 23)).padding(.horizontal, 13).padding(.vertical, 11)
    }
    private func postHeader(name: String, subtitle: String, avatarIndex: Int) -> some View {
        HStack(spacing: 9) {
            avatar(avatarIndex, size: 31)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 12, weight: .semibold))
                Text(subtitle).font(.system(size: 10))
            }
            Spacer(); Image(systemName: "ellipsis").font(.system(size: 19))
        }.padding(.horizontal, 12).frame(height: 51)
    }
    private var inbox: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "chevron.left"); Text("nia.outside").font(.system(size: 24, weight: .bold)); Image(systemName: "chevron.down").font(.system(size: 12)); Spacer(); Image(systemName: "square.and.pencil") }
                .font(.system(size: 22)).padding(17)
            HStack { Image(systemName: "magnifyingglass"); Text("Search"); Spacer() }
                .font(.system(size: 15)).foregroundStyle(.gray).padding(12)
                .background(Color(hex: 0xF1F1F1), in: RoundedRectangle(cornerRadius: 13)).padding(.horizontal, 16)
            HStack(spacing: 24) {
                ForEach(0..<4) { i in
                    VStack(spacing: 7) {
                        avatar(i, size: 61).overlay(alignment: .bottomTrailing) { Circle().fill(.green).frame(width: 12,height: 12).overlay { Circle().stroke(.white,lineWidth: 2) } }
                        Text(["Your note", "Mika", "Sami", "June"][i]).font(.system(size: 11))
                    }
                }
            }.padding(.vertical, 25)
            HStack { Text("Messages").font(.system(size: 17, weight: .bold)); Spacer(); Text("Requests").font(.system(size: 13, weight: .semibold)).foregroundStyle(.blue) }.padding(.horizontal, 17).padding(.bottom, 16)
            ForEach(0..<6) { i in
                HStack(spacing: 12) {
                    avatar(i % 4, size: 55)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(["Mika Chen", "Sami", "Sunday people 🌞", "June", "Nia", "Weekend plans"][i]).font(.system(size: 15, weight: i == 0 ? .semibold : .regular))
                        Text(["See you at 9?  ·  2m", "Sent you a photo  ·  15m", "You: Perfect, see you there!  ·  1h", "Loved this spot  ·  3h", "Liked a message  ·  5h", "Sami: Let's do it  ·  1d"][i]).font(.system(size: 12)).foregroundStyle(i == 0 ? .black : .gray)
                    }
                    Spacer(); if i == 0 { Circle().fill(.blue).frame(width: 8,height: 8) }; Image(systemName: "camera").font(.system(size: 23)).foregroundStyle(.gray)
                }.padding(.horizontal, 17).padding(.vertical, 12)
            }
        }.frame(maxHeight: .infinity, alignment: .top).clipped()
    }
    private var conversation: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "chevron.left"); avatar(2,size: 33)
                VStack(alignment: .leading,spacing: 3) { Text("Mika Chen").font(.system(size: 15,weight: .semibold)); Text("Active now").font(.system(size: 11)).foregroundStyle(.gray) }
                Spacer(); Image(systemName: "phone"); Image(systemName: "video")
            }.font(.system(size: 22)).padding(14)
            Divider()
            Text("TODAY 9:36 AM").font(.system(size: 10)).foregroundStyle(.gray).padding(.vertical, 17)
            VStack(spacing: 12) {
                bubble("Morning! Coffee before the walk?", sent: false)
                bubble("Absolutely ☀️", sent: true)
                HStack { Spacer(); photo("preview-coast", height: 120).frame(width: 175).clipShape(RoundedRectangle(cornerRadius: 15)) }
                bubble("Found our next weekend spot", sent: true)
                bubble("That looks unreal. Let's go!", sent: false)
            }.padding(.horizontal, 14)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                Image(systemName: "camera.fill").foregroundStyle(.white).frame(width: 31,height: 31).background(.blue,in: Circle())
                Text("See you at 9?").font(.system(size: 14)); Rectangle().fill(.blue).frame(width: 1,height: 18); Spacer(); Text("Send").font(.system(size: 14,weight: .semibold)).foregroundStyle(.blue)
            }.padding(8).overlay { Capsule().stroke(Color.gray.opacity(0.3)) }.padding(10)
            keyboard
        }.frame(maxHeight: .infinity)
    }
    private var keyboard: some View {
        VStack(spacing: 8) {
            HStack { Text("“9”"); Spacer(); Text("9:00"); Spacer(); Text("nine") }.font(.system(size: 14)).padding(.horizontal, 28).frame(height: 27)
            ForEach([Array("qwertyuiop"), Array("asdfghjkl"), Array("zxcvbnm")], id: \.self) { row in
                HStack(spacing: 5) {
                    if row.count == 7 { key("⇧", gray: true) }
                    ForEach(row,id: \.self) { key(String($0)) }
                    if row.count == 7 { key("⌫", gray: true) }
                }.padding(.horizontal,row.count == 9 ? 20 : 4)
            }
            HStack(spacing: 6) { key("123",gray: true); key("☺︎",gray: true); Text("space").font(.system(size: 15)).frame(width: 174,height: 39).background(.white,in: RoundedRectangle(cornerRadius: 5)); key("return",gray: true) }.padding(.horizontal,4)
            HStack { Image(systemName: "globe"); Spacer(); Image(systemName: "mic.fill") }.font(.system(size: 22)).padding(.horizontal, 21).padding(.top, 6)
        }.padding(.bottom, 8).background(Color(hex: 0xD1D4DA))
    }
    private func key(_ value: String, gray: Bool = false) -> some View {
        Text(value).font(.system(size: value.count > 1 ? 12 : 22)).frame(maxWidth: .infinity).frame(height: 39)
            .background(gray ? Color(hex: 0xAFB4BE) : .white, in: RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.22),radius: 0,y: 1)
    }
    private func bubble(_ text: String, sent: Bool) -> some View {
        Text(text).font(.system(size: 14)).padding(.horizontal, 14).padding(.vertical, 11)
            .foregroundStyle(sent ? .white : .black)
            .background(sent ? Color(hex: 0x6358E9) : Color(hex: 0xEFEFEF), in: RoundedRectangle(cornerRadius: 19))
            .frame(maxWidth: .infinity, alignment: sent ? .trailing : .leading)
    }
    private var profile: some View {
        VStack(alignment: .leading,spacing: 15) {
            HStack { Text("nia.outside").font(.system(size: 22, weight: .bold)); Spacer(); Image(systemName: "plus.app"); Image(systemName: "line.3.horizontal") }.font(.system(size: 23)).padding(.horizontal, 15)
            HStack(spacing: 23) {
                avatar(0,size: 82)
                ForEach([("128","posts"),("2,451","followers"),("816","following")],id: \.0) { count in VStack(spacing: 3) { Text(count.0).font(.system(size: 17,weight: .bold)); Text(count.1).font(.system(size: 11)) } }
            }.padding(.horizontal, 15)
            VStack(alignment: .leading,spacing: 4) {
                Text("Nia").font(.system(size: 13,weight: .bold)); Text("A camera, a coffee, somewhere new.\nBengaluru ↗ everywhere 🌿").font(.system(size: 12)); Text("niaoutside.com").foregroundStyle(Color(hex: 0x24496A)).font(.system(size: 12))
            }.padding(.horizontal,15)
            HStack { Text("Following"); Text("Message"); Image(systemName: "person.badge.plus") }.font(.system(size: 12,weight: .semibold)).frame(maxWidth: .infinity).padding(10).background(Color(hex: 0xEFEFEF),in: RoundedRectangle(cornerRadius: 7)).padding(.horizontal,15)
            HStack(spacing: 21) { ForEach(0..<4) { i in VStack(spacing: 6) { Image(["preview-coast","preview-coffee","preview-mountains","preview-city"][i]).resizable().scaledToFill().frame(width: 55,height: 55).clipShape(Circle()).padding(3).overlay { Circle().stroke(.gray.opacity(0.3)) }; Text(["weekends","coffee","outside","little things"][i]).font(.system(size: 10)) } } }.padding(.horizontal,17)
            HStack { Image(systemName: "square.grid.3x3").frame(maxWidth: .infinity); Image(systemName: "person.crop.square").foregroundStyle(.gray).frame(maxWidth: .infinity) }.font(.system(size: 23)).padding(.vertical,7)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(),spacing: 2),count: 3),spacing: 2) {
                ForEach(["preview-waterfall","preview-coast","preview-coffee","preview-city","preview-mountains","goal-movement"],id: \.self) { name in
                    Image(name).resizable().scaledToFill().frame(width: 129,height: 152).clipped()
                }
            }
        }.frame(maxHeight: .infinity, alignment: .top).clipped()
    }
    private var youtubeFeed: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "play.rectangle.fill").foregroundStyle(.red); Text("YouTube").font(.system(size: 23,weight: .bold)); Spacer(); Image(systemName: "airplay.video"); Image(systemName: "bell"); Image(systemName: "magnifyingglass") }.font(.system(size: 21)).padding(15)
            HStack { ForEach(["All","Outdoors","Photography","Music"],id: \.self) { tag in Text(tag).font(.system(size: 12,weight: .medium)).padding(9).background(tag == "All" ? .black : Color(hex: 0xEEEEEE),in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(tag == "All" ? .white : .black) } }.padding(.bottom,12)
            photo("preview-mountains",height: 218).overlay(alignment: .bottomTrailing) { Text("18:42").font(.system(size: 12,weight: .semibold)).padding(4).background(.black.opacity(0.8),in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(.white).padding(8) }
            postHeader(name: "A weekend above the clouds",subtitle: "Outside Journal · 284K views · 2 weeks ago",avatarIndex: 1)
            if !hidden.contains(.reels) {
                HStack { Image(systemName: "bolt.fill").foregroundStyle(.red); Text("Shorts").font(.system(size: 19,weight: .bold)); Spacer() }.padding(14)
                HStack(spacing: 8) { photo("preview-coast",height: 200); photo("preview-city",height: 200) }.padding(.horizontal,12)
            } else {
                photo("preview-camera",height: 218)
                postHeader(name: "Make more with the camera you own",subtitle: "Mika Studio · 92K views · 3 days ago",avatarIndex: 2)
            }
        }.frame(maxHeight: .infinity,alignment: .top).clipped()
    }
    private var navigation: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                nav("house.fill")
                if !hidden.contains(.explore) { nav("magnifyingglass") }
                if !hidden.contains(.reels) || (spotlightsReels && holdsReelsSlot) {
                    nav("play.rectangle")
                        .opacity(hidden.contains(.reels) ? 0 : 1)
                        .overlay {
                            if spotlightsReels { ReelsSpotlight() }
                        }
                }
                nav(youtube ? "plus.circle" : "paperplane")
                avatar(0,size: 24).frame(maxWidth: .infinity)
            }.frame(height: 48)
        }.background(.white)
    }
    private func nav(_ symbol: String) -> some View { Image(systemName: symbol).font(.system(size: 23)).frame(maxWidth: .infinity).transition(.scale.combined(with: .opacity)) }
    private func avatar(_ index: Int,size: CGFloat) -> some View { Image(["preview-nia","preview-sami","preview-mika","preview-june"][index]).resizable().scaledToFill().frame(width: size,height: size).clipShape(Circle()) }
    private func photo(_ name: String,height: CGFloat) -> some View { GeometryReader { g in Image(name).resizable().scaledToFill().frame(width: g.size.width,height: height).clipped() }.frame(height: height) }
}

private struct ReelsSpotlight: View {
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var pulsed = false

    var body: some View {
        Circle()
            .strokeBorder(Color(hex: 0xE51D3A), lineWidth: 3.5)
            .background(Color(hex: 0xF33554).opacity(0.08), in: Circle())
            .frame(width: 48, height: 48)
            .overlay {
                Circle()
                    .strokeBorder(Color(hex: 0xF33554).opacity(pulsed ? 0 : 0.56), lineWidth: 2)
                    .scaleEffect(pulsed ? 1.54 : 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                guard !reduceMotion else { pulsed = true; return }
                withAnimation(.easeOut(duration: 0.85).repeatCount(2, autoreverses: false)) { pulsed = true }
            }
    }
}

// A bundled, silent reel keeps the first impression immediate and offline.
private struct WelcomeReel: UIViewRepresentable {
    let playing: Bool
    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        let player = AVQueuePlayer()
        var looper: AVPlayerLooper?
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            let videoLayer = layer as! AVPlayerLayer
            videoLayer.player = player
            videoLayer.videoGravity = .resizeAspectFill
            player.isMuted = true
            if let url = Bundle.main.url(forResource: "welcome-luxury", withExtension: "mp4") {
                looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
    func makeUIView(context: Context) -> PlayerView { PlayerView() }
    func updateUIView(_ view: PlayerView, context: Context) {
        if playing { view.player.play() } else { view.player.pause() }
    }
    static func dismantleUIView(_ view: PlayerView, coordinator: ()) {
        view.player.pause()
        view.looper?.disableLooping()
        view.player.removeAllItems()
        (view.layer as? AVPlayerLayer)?.player = nil
    }
}

struct WelcomeArtwork: View {
    @Environment(\.onboardingHeight) private var availableHeight
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scene
    @State private var settled = false
    @State private var focused = false
    @State private var removed = false
    @State private var pressingSwitch = false

    var body: some View {
        GeometryReader { geometry in
            let phoneWidth = min(242.0, (geometry.size.height - 28) / (864.0 / 410))
            ZStack {
                RoundedRectangle(cornerRadius: 115)
                    .fill(LinearGradient(colors: [PaywallPalette.peach, PaywallPalette.blush],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: phoneWidth * 1.3, height: phoneWidth * 1.55)
                    .rotationEffect(.degrees(focused ? -25 : 28))
                    .scaleEffect(settled ? 1 : 0.6)
                    .offset(x: 10, y: 30)
                Ellipse().strokeBorder(PaywallPalette.outline.opacity(0.45), lineWidth: 1)
                    .frame(width: phoneWidth * 1.55, height: phoneWidth * 1.25)
                    .rotationEffect(.degrees(focused ? -35 : -55))
                    .offset(y: -25)
                ReelPhonePreview(removed: removed)
                    .frame(width: 410, height: 864)
                    .scaleEffect(phoneWidth / 410)
                    .frame(width: phoneWidth, height: phoneWidth * 864 / 410)
                    .shadow(color: PaywallPalette.plum.opacity(0.22), radius: 22, x: 8, y: 18)
                    .rotation3DEffect(.degrees(focused ? 33 : settled ? 5 : 24), axis: (x: 1, y: -0.12, z: 0), perspective: 0.65)
                    .rotationEffect(.degrees(settled ? (focused ? -5 : -9) : -22))
                    .offset(x: focused ? 0 : -geometry.size.width * 0.10, y: settled ? (focused ? 32 : -4) : 85)
                    .scaleEffect(settled ? 1 : 0.75)
                    .opacity(settled ? 1 : 0)
                HStack(spacing: 10) {
                    Image(systemName: "power").font(.system(size: 18, weight: .bold))
                    Text("Turn off Reels").font(.system(size: 14, weight: .semibold))
                    Capsule().fill(removed ? Color.black : Color.gray.opacity(0.3))
                        .frame(width: 44, height: 27)
                        .overlay(alignment: removed ? .trailing : .leading) {
                            Circle().fill(.white).frame(width: 23, height: 23).padding(2)
                        }
                }
                .padding(15).background(.white, in: RoundedRectangle(cornerRadius: 19))
                .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(PaywallPalette.outline, lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 14, y: 8)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "hand.point.up.left.fill").font(.system(size: 35))
                        .foregroundStyle(PaywallPalette.plum)
                        .offset(x: 14, y: pressingSwitch ? 14 : 42)
                        .scaleEffect(pressingSwitch ? 0.85 : 1)
                        .opacity(focused && !removed ? 1 : 0)
                }
                .offset(y: -geometry.size.height * 0.36)
                .scaleEffect(focused ? 1 : 0.75).opacity(focused ? 1 : 0)
                Image("MascotRest").resizable().scaledToFit()
                    .frame(width: 92, height: 104)
                    .rotationEffect(.degrees(focused ? -7 : 8))
                    .shadow(color: PaywallPalette.plum.opacity(0.14), radius: 12, y: 8)
                    .offset(x: geometry.size.width * 0.35, y: 32)
                    .scaleEffect(settled ? 1 : 0.65).opacity(settled ? 1 : 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: min(510, max(280, availableHeight - 155)))
        .accessibilityHidden(true)
        .task(id: reduceMotion) {
            if reduceMotion { settled = true; removed = true; return }
            do {
                try await Task.sleep(for: .milliseconds(620))
                withAnimation(.spring(response: 0.85, dampingFraction: 0.8)) { settled = true }
                try await Task.sleep(for: .seconds(1.1))
                withAnimation(.easeInOut(duration: 0.8)) { focused = true }
                try await Task.sleep(for: .seconds(1))
                withAnimation(.easeInOut(duration: 0.35)) { pressingSwitch = true }
                try await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeInOut(duration: 0.65)) { removed = true }
                try await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeInOut(duration: 0.8)) { focused = false }
            } catch { return }
        }
    }

}

struct ReelPhonePreview: View {
    let removed: Bool
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scene
    var body: some View {
        ZStack {
            Color.black
            ZStack {
                Image("WelcomeReelPoster").resizable().scaledToFill().frame(width: 390, height: 844).clipped()
                if !reduceMotion { WelcomeReel(playing: scene == .active && !removed).frame(width: 390, height: 844) }
                LinearGradient(colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.8)],
                               startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("9:41").font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "wifi"); Image(systemName: "battery.100percent")
                    }.font(.system(size: 14)).padding(.top, 15)
                    HStack {
                        Text("Reels").font(.system(size: 28, weight: .bold))
                        Spacer()
                        Image(systemName: "speaker.slash.fill").font(.system(size: 18))
                    }.padding(.top, 20)
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("A little escape.").font(.system(size: 23, weight: .semibold))
                            Text("Keep the good. Lose the endless.").font(.system(size: 15))
                        }
                        Spacer()
                        VStack(spacing: 24) {
                            Image(systemName: "heart")
                            Image(systemName: "bubble.right")
                            Image(systemName: "paperplane")
                        }.font(.system(size: 27))
                    }.padding(.bottom, 24)
                    HStack {
                        ForEach(["house", "magnifyingglass", "plus.app", "play.rectangle.fill", "person.crop.circle"], id: \.self) { icon in
                            Image(systemName: icon).frame(maxWidth: .infinity)
                        }
                    }.font(.system(size: 25)).padding(.bottom, 25)
                }.foregroundStyle(.white).padding(.horizontal, 25).frame(width: 390, height: 844)
            }
            .frame(width: 390, height: 844)
            .overlay {
                if removed {
                    PhoneDemo(hidden: [.reels], showsAd: true).screen
                        .frame(width: 390, height: 844).background(.white)
                        .transition(.opacity.combined(with: .offset(y: 24)))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 49))
            Capsule().fill(.black).frame(width: 110, height: 31).offset(y: -395)
            Capsule().fill(.white.opacity(0.8)).frame(width: 125, height: 5).offset(y: 411)
        }
        .clipShape(RoundedRectangle(cornerRadius: 58))
        .overlay(RoundedRectangle(cornerRadius: 58).strokeBorder(
            LinearGradient(colors: [.white.opacity(0.8), .black, .gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4))
    }
}

struct SavedArtwork: View {
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle().fill(PaywallPalette.selection).frame(width: 222, height: 222)
                .scaleEffect(appeared ? 1 : 0.65)
            Circle().strokeBorder(PaywallPalette.blush.opacity(0.6), lineWidth: 1)
                .frame(width: 248, height: 248).scaleEffect(appeared ? 1.08 : 0.8)
            Image("MascotRest").resizable().scaledToFit()
                .frame(height: 202)
                .scaleEffect(appeared ? 1 : 0.8)
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: 0x232D21))
                .frame(width: 45, height: 45)
                .background(PaywallPalette.blush, in: Circle())
                .scaleEffect(appeared ? 1 : 0.35)
                .opacity(appeared ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(18)
        }
        .frame(height: 249)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.53, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

struct GoalCard: View {
    @Environment(\.onboardingHeight) private var availableHeight
    let goal: Goal
    let selected: Bool
    let action: () -> Void
    @Environment(\.supermodReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Button(action: { Haptics.selection(); action() }) {
            GeometryReader { proxy in
                Image("goal-\(goal.rawValue)").resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(PaywallPalette.plum)
                    .clipped()
            }
            .overlay { LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .center, endPoint: .bottom) }
            .overlay(alignment: .topTrailing) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? PaywallPalette.blush : .white)
                    .padding(11)
                    .shadow(radius: 3)
            }
            .overlay(alignment: .bottomLeading) {
                Text(goal.title).font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading).foregroundStyle(.white).padding(12)
            }
            .frame(height: textSize.isAccessibilitySize ? 220 : min(220, max(150, (availableHeight - 140) / 2)))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(selected ? PaywallPalette.blush : .clear, lineWidth: 2) }
        }
        .buttonStyle(PressStyle())
        .animation(reduceMotion ? nil : .onboardingSpring, value: selected)
        .accessibilityLabel(goal.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ServiceOrbit: View {
    @State private var arrived = false
    @Environment(\.supermodReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 24) {
            ForEach(Array(SocialPlatform.allCases.enumerated()), id: \.offset) { index, platform in
                platform.emblem.scaleEffect(1.2)
                    .offset(y: arrived ? 0 : 60 + Double(index * 20))
                    .opacity(arrived ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.7,dampingFraction: 0.65).delay(Double(index) * 0.18),value: arrived)
            }
        }.frame(maxWidth: .infinity).frame(height: 140).onAppear { arrived = true }
    }
}

struct CrowdIllustration: View {
    @State private var appeared = false
    @Environment(\.supermodReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 28) {
            Heading(title: "It’s not your fault",centered: true,hero: true)
            HStack(alignment: .bottom,spacing: 20) {
                Image(systemName: "figure.stand").font(.system(size: 44,weight: .light)).foregroundStyle(Palette.ink).padding(.bottom, 12)
                VStack(spacing: 6) {
                    ForEach(0..<6) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<(row + 3),id: \.self) { _ in
                                Image(systemName: "figure.stand").font(.system(size: 24,weight: .ultraLight))
                                    .foregroundStyle(Palette.muted.opacity(0.45 + Double(row) * 0.08))
                            }
                        }.padding(5).background(Palette.surface)
                            .offset(x: Double(5 - row) * 7,y: appeared ? 0 : 30)
                            .opacity(appeared ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(Double(row) * 0.13),value: appeared)
                    }
                }
            }.frame(height: 280)
            Text("You’re one person. The feed is designed to keep going.\nYou can choose where it stops.")
                .font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).onAppear { appeared = true }
    }
}

struct FeatureComparison: View {
    @State private var rows = 0
    @Environment(\.supermodReduceMotion) private var reduceMotion
    private let entries = [
        ("Instagram Reels", "Messages and profiles"),
        ("YouTube Shorts", "Search and regular videos"),
        ("Sponsored posts", "Posts from people you follow"),
        ("Explore and suggestions", "The connections you choose"),
        ("The whole Instagram feed", "A direct route to messages")
    ]
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("You can hide").foregroundStyle(Palette.muted).frame(maxWidth: .infinity,alignment: .leading); Text("You can keep").frame(maxWidth: .infinity,alignment: .leading) }
                .font(.subheadline.weight(.bold)).padding(17)
            ForEach(Array(entries.enumerated()),id: \.offset) { i, row in
                Divider()
                HStack(alignment: .top,spacing: 12) {
                    Text(row.0).foregroundStyle(Palette.muted).frame(maxWidth: .infinity,alignment: .leading)
                    Label(row.1,systemImage: "checkmark").frame(maxWidth: .infinity,alignment: .leading)
                }.font(.system(size: 12)).lineSpacing(3).padding(17)
                    .opacity(i < rows ? 1 : 0).offset(y: i < rows ? 0 : 9)
            }
        }.background(Palette.canvas,in: RoundedRectangle(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).stroke(Palette.line.opacity(0.6)) }
            .shadow(color: .black.opacity(0.06),radius: 16,y: 6).padding(.top, 65)
            .task {
                for count in 1...entries.count {
                    do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { rows = count }
                }
            }
    }
}

struct LocalPrivacyIllustration: View {
    @State private var arrived = false
    @Environment(\.supermodReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 36).fill(Palette.surface).frame(width: 184,height: 280)
                    .overlay { RoundedRectangle(cornerRadius: 36).stroke(Palette.line,lineWidth: 2) }
                VStack(spacing: 14) {
                    Capsule().fill(Palette.ink).frame(width: 56,height: 16).padding(.bottom, 19)
                    Image(systemName: "lock.shield.fill").font(.system(size: 54)).foregroundStyle(PaywallPalette.plum)
                    ForEach(0..<3) { i in
                        HStack { Capsule().fill(Palette.line).frame(width: 55,height: 7); Spacer(); Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0x529A73)) }
                            .padding(.horizontal,30).opacity(arrived ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeOut.delay(Double(i) * 0.2),value: arrived)
                    }
                }.frame(width: 184)
                Text("Saved on your iPhone").font(.caption.weight(.semibold)).padding(13)
                    .background(Palette.canvas,in: Capsule()).shadow(color: .black.opacity(0.1),radius: 12,y: 4).offset(y: 138)
            }.frame(height: 320)
            Text("No extra account to create.").font(.headline)
            Text("Your setup and preferences stay on this device.\nInstagram handles its own sign-in.")
                .font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).onAppear { arrived = true }
    }
}


struct SupermodContainerIllustration: View {
    @State private var arrived = false
    @Environment(\.supermodReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 8) { BrandMascot(size: 32); Text("Inside Supermod").font(.headline) }
            HStack(spacing: 25) {
                ForEach(Array(SocialPlatform.allCases.enumerated()),id: \.offset) { index, platform in
                    VStack(spacing: 8) {
                        platform.emblem
                        Text(platform.title).font(.caption2.weight(.medium))
                    }
                    .offset(y: arrived ? 0 : 25).opacity(arrived ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(duration: 0.6,bounce: 0.25).delay(Double(index) * 0.15),value: arrived)
                }
            }
            Label("Your chosen distractions hidden here",systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(Palette.muted)
        }.padding(22).frame(maxWidth: .infinity)
            .background(Palette.surface,in: RoundedRectangle(cornerRadius: 30))
            .overlay { RoundedRectangle(cornerRadius: 30).stroke(Palette.line,lineWidth: 1) }
            .onAppear { arrived = true }
    }
}

/// A single warm-red flash marks the target; soft puffs disperse as it is removed.
private struct FeatureRemovalPoof: View {
    var progress: Double
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.red.opacity(0.28 * (1 - progress)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.8 * (1 - progress)), lineWidth: 3))
                ForEach(0..<12) { index in
                    let theta = Double(index) * .pi / 6
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 24 + Double(index % 3) * 8))
                        .foregroundStyle(index % 3 == 0 ? Color(hex: 0xED7892) : Color(hex: 0xFBE4E9))
                        .scaleEffect(0.25 + progress * 1.25)
                        .offset(x: cos(theta) * geometry.size.width * 0.45 * progress,
                                y: sin(theta) * min(geometry.size.height * 0.45, 135) * progress)
                        .opacity(1 - progress)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
