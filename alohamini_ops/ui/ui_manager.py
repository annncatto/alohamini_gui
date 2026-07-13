from qt_compat import (
    QFrame,
    QGridLayout,
    QLabel,
    QScrollArea,
    QSizeGrip,
    QSizePolicy,
    QSplitter,
    QTabWidget,
    QHBoxLayout,
    QVBoxLayout,
    QWidget,
    Qt,
)
from ui.log_panel import LogPanel
from ui.tabs.calibration_tab import CalibrationTab
from ui.tabs.camera_panel import CameraPanel
from ui.tabs.connection_tab import ConnectionTab
from ui.tabs.dataset_tab import DatasetTab
from ui.tabs.deploy_tab import DeployTab
from ui.tabs.diagnostics_tab import DiagnosticsTab
from ui.tabs.map_panel import MapPanel
from ui.tabs.sensor_panel import SensorPanel
from ui.tabs.teleop_tab import TeleopTab


class UiManager:
    def __init__(self, context):
        self.context = context
        self.connection_tab = ConnectionTab(context)
        self.teleop_tab = TeleopTab()
        self.dataset_tab = DatasetTab(context)
        self.deploy_tab = DeployTab(context)
        self.calibration_tab = CalibrationTab()
        self.diagnostics_tab = DiagnosticsTab()
        self.camera_panel = CameraPanel()
        self.map_panel = MapPanel()
        self.sensor_panel = SensorPanel()
        self.log_panel = LogPanel()
        self.status_line = QLabel("机器人: 未连接 | Host: 未知 | 数据: 待机")
        self.robot_state = QLabel("机器人\n未连接")
        self.host_state = QLabel("树莓派 Host\n未知")
        self.link_state = QLabel("网络链路\n未知")
        self.data_state = QLabel("数据采集\n待机")
        self.host_alert = QLabel("")
        self.visual_status = QLabel("运行状态\n待机")
        self.action_state = QLabel("x=0.000  y=0.000  theta=0.0  lift=0")
        self.resize_grip = QSizeGrip(None)
        self.diagnostic_status = self.diagnostics_tab.status_output

    def build(self) -> QWidget:
        root = QWidget()
        root_layout = QVBoxLayout(root)
        root_layout.setContentsMargins(8, 8, 8, 8)
        root_layout.setSpacing(8)
        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.addWidget(self._build_left())
        splitter.addWidget(self._build_right())
        splitter.setSizes([400, 880])
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setChildrenCollapsible(False)

        root_layout.addWidget(splitter, 1)
        root_layout.addWidget(self.status_line)
        bottom = QHBoxLayout()
        bottom.setContentsMargins(0, 0, 0, 0)
        self.action_state.setObjectName("actionState")
        bottom.addWidget(self.action_state)
        bottom.addWidget(self.resize_grip, 0, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignBottom)
        root_layout.addLayout(bottom)
        return root

    def _build_left(self) -> QWidget:
        panel = QWidget()
        panel.setMinimumWidth(380)
        panel.setMaximumWidth(460)
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(0, 0, 8, 0)

        tabs = QTabWidget()
        tabs.addTab(self._scroll_page(self.connection_tab), "连接")
        tabs.addTab(self._scroll_page(self.teleop_tab), "遥操")
        tabs.addTab(self._scroll_page(self.dataset_tab), "数据")
        tabs.addTab(self._scroll_page(self.deploy_tab), "部署")
        tabs.addTab(self._scroll_page(self.calibration_tab), "校准")
        tabs.addTab(self._scroll_page(self.diagnostics_tab), "诊断")
        layout.addWidget(tabs, 1)
        return panel

    def _build_right(self) -> QWidget:
        panel = QWidget()
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(8, 0, 0, 0)
        self.host_alert.setObjectName("hostAlert")
        self.host_alert.setWordWrap(True)
        self.host_alert.hide()
        layout.addWidget(self.host_alert)

        summary = QFrame()
        summary.setObjectName("summaryPanel")
        summary_layout = QGridLayout(summary)
        for i, widget in enumerate([self.robot_state, self.host_state, self.link_state, self.data_state]):
            widget.setObjectName("summaryTile")
            widget.setAlignment(Qt.AlignmentFlag.AlignCenter)
            widget.setWordWrap(True)
            summary_layout.addWidget(widget, 0, i)

        tabs = QTabWidget()
        tabs.addTab(self._build_overview(), "总览")
        tabs.addTab(self.camera_panel, "相机")
        tabs.addTab(self.map_panel, "地图")
        tabs.addTab(self.sensor_panel, "传感器")

        splitter = QSplitter(Qt.Orientation.Vertical)
        splitter.addWidget(summary)
        splitter.addWidget(tabs)
        splitter.setSizes([80, 620])
        splitter.setStretchFactor(0, 0)
        splitter.setStretchFactor(1, 1)
        splitter.setChildrenCollapsible(True)
        layout.addWidget(splitter, 1)
        return panel

    def _build_overview(self) -> QWidget:
        visual = QFrame()
        visual.setObjectName("visualPanel")
        visual.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        visual_layout = QVBoxLayout(visual)
        visual_layout.setContentsMargins(12, 12, 12, 12)
        visual_layout.setSpacing(10)
        self.visual_status.setObjectName("summaryTile")
        self.visual_status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.visual_status.setWordWrap(True)
        visual_layout.addWidget(self.visual_status)
        visual_layout.addWidget(self.log_panel, 1)
        return visual

    def _placeholder(self, text: str) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        label = QLabel(text)
        label.setObjectName("visualPlaceholder")
        label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        label.setWordWrap(True)
        layout.addWidget(label, 1)
        return page

    def _scroll_page(self, widget: QWidget) -> QScrollArea:
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setWidget(widget)
        return scroll
