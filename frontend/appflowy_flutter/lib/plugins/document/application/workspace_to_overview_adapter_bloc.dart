import 'package:appflowy/workspace/application/view/view_listener.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/protobuf.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_to_overview_adapter_bloc.freezed.dart';

class WorkspaceToOverviewAdapterBloc extends Bloc<
    WorkspaceToOverviewAdapterEvent, WorkspaceToOverviewAdapterState> {
  final String viewId;

  final ViewListener _listener;

  WorkspaceToOverviewAdapterBloc({
    required this.viewId,
  })  : _listener = ViewListener(viewId: viewId),
        super(WorkspaceToOverviewAdapterState.initial(viewId)) {
    on<WorkspaceToOverviewAdapterEvent>((event, emit) async {
      await event.map(
        initial: (e) async {
          _listener.start(
            onViewUpdated: _onViewUpdated,
            onViewChildViewsUpdated: _onChildViewsUpdated,
            onViewMoveToTrash: _onDeleted,
            onViewRestored: _onViewRestored,
          );
        },
        viewDidUpdate: (e) async {},
      );
    });
  }

  void _onViewUpdated(UpdateViewNotifiedValue updatedView) {}

  void _onChildViewsUpdated(ChildViewUpdatePB updatedChildViews) {}

  void _onViewRestored(RestoreViewNotifiedValue restoredView) {}

  void _onDeleted(MoveToTrashNotifiedValue trashedView) {}
}

@freezed
class WorkspaceToOverviewAdapterEvent with _$WorkspaceToOverviewAdapterEvent {
  const factory WorkspaceToOverviewAdapterEvent.initial() = Initial;
  const factory WorkspaceToOverviewAdapterEvent.viewDidUpdate(ViewPB view) =
      ViewDidUpdate;
}

@freezed
class WorkspaceToOverviewAdapterState with _$WorkspaceToOverviewAdapterState {
  const factory WorkspaceToOverviewAdapterState({
    required String viewId,
  }) = _WorkspaceToOverviewAdapterState;

  factory WorkspaceToOverviewAdapterState.initial(String viewId) =>
      WorkspaceToOverviewAdapterState(
        viewId: viewId,
      );
}
