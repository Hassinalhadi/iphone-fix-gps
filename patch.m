- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.11 alpha:1.0];
    
    // عنوان الواجهة
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"GPS Location Simulator";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];
    
    // معرف الجهاز المختصر (8 خانات)
    UILabel *idLabel = [[UILabel alloc] init];
    idLabel.text = [NSString stringWithFormat:@"Device ID: %@", GetShortDeviceID()];
    idLabel.textColor = [UIColor systemGrayColor];
    idLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    idLabel.textAlignment = NSTextAlignmentCenter;
    idLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:idLabel];
    
    // حقل إدخال الكود
    self.codeField = [[UITextField alloc] init];
    self.codeField.placeholder = @"Enter Activation Key";
    self.codeField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.codeField.textColor = [UIColor whiteColor];
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.layer.cornerRadius = 10;
    self.codeField.delegate = self;
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.codeField];
    
    // زر التفعيل
    UIButton *actBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [actBtn setTitle:@"Activate" forState:UIControlStateNormal];
    actBtn.backgroundColor = [UIColor systemRedColor];
    [actBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    actBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    actBtn.layer.cornerRadius = 10;
    actBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [actBtn addTarget:self action:@selector(handleActivate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:actBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:80],
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [idLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [idLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        
        [self.codeField.topAnchor constraintEqualToAnchor:idLabel.bottomAnchor constant:30],
        [self.codeField.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.codeField.widthAnchor constraintEqualToConstant:280],
        [self.codeField.heightAnchor constraintEqualToConstant:44],
        
        [actBtn.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:15],
        [actBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [actBtn.widthAnchor constraintEqualToConstant:280],
        [actBtn.heightAnchor constraintEqualToConstant:44]
    ]];
}
