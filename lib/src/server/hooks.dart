import "dart:async";
import "dart:convert";
import "dart:io";

import "../common.dart";

class HookMiddleware {
  // TODO: Close this, but where?
  final StreamController<HookEvent> _eventController =
      StreamController<HookEvent>();
  Stream<HookEvent> get onEvent => _eventController.stream;

  void handleHookRequest(HttpRequest request) {
    if (request.method != "POST") {
      request.response
        ..write("Only POST is Supported")
        ..close();
      return;
    }

    if (request.headers.value("X-GitHub-Event") == null) {
      request.response
        ..write("X-GitHub-Event must be specified.")
        ..close();
      return;
    }

    request.transform(const Utf8Decoder()).join().then((content) {
      _eventController.add(HookEvent.fromJSON(
          request.headers.value("X-GitHub-Event"),
          jsonDecode(content) as Map<String, dynamic>));
      request.response
        ..write(jsonEncode({"handled": _eventController.hasListener}))
        ..close();
    });
  }
}

class HookServer extends HookMiddleware {
  final String host;
  final int port;

  HttpServer _server;

  HookServer(this.port, [this.host = "0.0.0.0"]);

  void start() {
    HttpServer.bind(host, port).then((HttpServer server) {
      _server = server;
      server.listen((request) {
        if (request.uri.path == "/hook") {
          handleHookRequest(request);
        } else {
          request.response
            ..statusCode = 404
            ..write("404 - Not Found")
            ..close();
        }
      });
    });
  }

  Future stop() => _server.close();
}

class HookEvent {
  HookEvent();

  factory HookEvent.fromJSON(String event, Map<String, dynamic> json) {
    if (event == "pull_request") {
      return PullRequestEvent.fromJSON(json);
    } else if (event == "issues") {
      return IssueEvent.fromJSON(json);
    } else if (event == "issue_comment") {
      return IssueCommentEvent.fromJSON(json);
    } else if (event == "repository") {
      return RepositoryEvent.fromJSON(json);
    }
    return UnknownHookEvent(event, json);
  }
}

class UnknownHookEvent extends HookEvent {
  final String event;
  final Map<String, dynamic> data;

  UnknownHookEvent(this.event, this.data);
}

class RepositoryEvent extends HookEvent {
  String action;
  Repository repository;
  User sender;

  static RepositoryEvent fromJSON(Map<String, dynamic> json) {
    return RepositoryEvent()
      ..action = json["action"]
      ..repository =
          Repository.fromJSON(json["repository"] as Map<String, dynamic>)
      ..sender = User.fromJson(json["sender"] as Map<String, dynamic>);
  }
}

class IssueCommentEvent extends HookEvent {
  String action;
  Issue issue;
  IssueComment comment;

  static IssueCommentEvent fromJSON(Map<String, dynamic> json) {
    return IssueCommentEvent()
      ..action = json["action"]
      ..issue = Issue.fromJSON(json["issue"] as Map<String, dynamic>)
      ..comment =
          IssueComment.fromJSON(json["comment"] as Map<String, dynamic>);
  }
}

class ForkEvent extends HookEvent {
  Repository forkee;
  User sender;

  static ForkEvent fromJSON(Map<String, dynamic> json) {
    return ForkEvent()
      ..forkee = Repository.fromJSON(json["forkee"] as Map<String, dynamic>)
      ..sender = User.fromJson(json["sender"] as Map<String, dynamic>);
  }
}

class IssueEvent extends HookEvent {
  String action;
  User assignee;
  IssueLabel label;
  Issue issue;
  User sender;
  Repository repository;

  static IssueEvent fromJSON(Map<String, dynamic> json) {
    return IssueEvent()
      ..action = json["action"]
      ..assignee = User.fromJson(json["assignee"] as Map<String, dynamic>)
      ..label = IssueLabel.fromJSON(json["label"] as Map<String, dynamic>)
      ..issue = Issue.fromJSON(json["issue"] as Map<String, dynamic>)
      ..repository =
          Repository.fromJSON(json["repository"] as Map<String, dynamic>)
      ..sender = User.fromJson(json["sender"] as Map<String, dynamic>);
  }
}

class PullRequestEvent extends HookEvent {
  String action;
  int number;
  PullRequest pullRequest;
  User sender;
  Repository repository;

  static PullRequestEvent fromJSON(Map<String, dynamic> json) {
    return PullRequestEvent()
      ..action = json["action"]
      ..number = json["number"]
      ..repository =
          Repository.fromJSON(json["repository"] as Map<String, dynamic>)
      ..pullRequest =
          PullRequest.fromJSON(json["pull_request"] as Map<String, dynamic>)
      ..sender = User.fromJson(json["sender"] as Map<String, dynamic>);
  }
}
