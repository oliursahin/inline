import Combine
import InlineKit
import InlineUI
import Logger
import RealtimeAPI
import SwiftUI

struct ChatView: View {
  var peerId: Peer
  var preview: Bool

  @State var text: String = ""
  @State var textViewHeight: CGFloat = 36

  @EnvironmentStateObject var fullChatViewModel: FullChatViewModel
  @EnvironmentObject var nav: Navigation
  @EnvironmentObject var data: DataManager

  @Environment(\.appDatabase) var database
  @Environment(\.scenePhase) var scenePhase

  @Environment(\.realtime) var realtime

  @ObservedObject var composeActions: ComposeActions = .shared

  func currentComposeAction() -> ApiComposeAction? {
    composeActions.getComposeAction(for: peerId)?.action
  }

  @State var currentTime = Date()

  @State var apiState: RealtimeAPIState = .connecting

  let timer = Timer.publish(
    every: 60, // 1 minute
    on: .main,
    in: .common
  ).autoconnect()

  static let formatter = RelativeDateTimeFormatter()
  func getLastOnlineText(date: Date?) -> String {
    guard let date else { return "" }

    let diffSeconds = Date().timeIntervalSince(date)
    if diffSeconds < 60 {
      return "last seen just now"
    }

    Self.formatter.dateTimeStyle = .named
    return "last seen \(Self.formatter.localizedString(for: date, relativeTo: Date()))"
  }

  var isPrivateChat: Bool {
    fullChatViewModel.peer.isPrivate
  }

  var isThreadChat: Bool {
    fullChatViewModel.peer.isThread
  }

  var subtitle: String {
    if apiState != .connected {
      getStatusTextForChatHeader(realtime.apiState)
    } else if let composeAction = currentComposeAction() {
      composeAction.toHumanReadableForIOS()
    } else {
      ""
    }
//    } else if let online = fullChatViewModel.peerUser?.online {
//      online
//        ? "online"
//        : (
//          fullChatViewModel.peerUser?.lastOnline != nil
//            ? getLastOnlineText(date: fullChatViewModel.peerUser?.lastOnline) : "offline"
//        )
//    } else {
//      "last seen recently"
//    }
  }

  init(peer: Peer, preview: Bool = false) {
    peerId = peer
    self.preview = preview
    _fullChatViewModel = EnvironmentStateObject { env in
      FullChatViewModel(db: env.appDatabase, peer: peer)
    }
  }

  // MARK: - Body

  var body: some View {
    ChatViewUIKit(
      peerId: peerId,
      chatId: fullChatViewModel.chat?.id ?? 0,
      spaceId: fullChatViewModel.chat?.spaceId ?? 0
    )
    .edgesIgnoringSafeArea(.all)
    .onReceive(timer) { _ in
      currentTime = Date()
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        header
      }
      if let user = fullChatViewModel.peerUserInfo {
        ToolbarItem(placement: .topBarTrailing) {
          UserAvatar(userInfo: user)
        }
      } else if let emoji = fullChatViewModel.chat?.emoji, isThreadChat {
        ToolbarItem(placement: .topBarTrailing) {
          Text(
            String(describing: emoji).replacingOccurrences(of: "Optional(\"", with: "")
              .replacingOccurrences(of: "\")", with: "")
          )
          .font(.customTitle())
        }
      }
    }
    .overlay(alignment: .top) {
      if preview {
        header
          .frame(height: 45)
          .frame(maxWidth: .infinity)
          .background(.ultraThickMaterial)
      }
    }
    .navigationBarHidden(false)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarTitleDisplayMode(.inline)
    .onAppear {
      fetch()
    }
    .onChange(of: scenePhase) { _, scenePhase_ in
      switch scenePhase_ {
        case .active:

          fetch()

        default:
          break
      }
    }
    .environmentObject(fullChatViewModel)
  }

  @ViewBuilder
  var header: some View {
    VStack(spacing: 0) {
      Text(title)
        .fontWeight(.semibold)

      if !isCurrentUser, isPrivateChat, !subtitle.isEmpty {
        HStack {
          if let composeAction = currentComposeAction() {
            AnimatedDots(dotSize: 3)
          }

          Text(subtitle.lowercased())
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, -2)
        .fixedSize()
      }
    }
    .fixedSize()
    .onAppear {
      apiState = realtime.apiState
    }
    .onReceive(realtime.apiStatePublisher, perform: { nextApiState in
      apiState = nextApiState
    })
  }

  func fetch() {
    fullChatViewModel.refetchChatView()
  }
}

struct CustomButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.8 : 1.0)
      .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
  }
}
