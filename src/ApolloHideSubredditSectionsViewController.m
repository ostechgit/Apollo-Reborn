#import "ApolloHideSubredditSectionsViewController.h"
#import "UserDefaultConstants.h"

// Kept in the same order they normally appear in the Subreddits list.
static NSArray<NSString *> *ApolloHideSubredditSectionsKinds(void) {
    return @[@"Favorites", @"Multireddits", @"Moderator"];
}

static NSString *ApolloHideSubredditSectionsKindSubtitle(NSString *kind) {
    if ([kind isEqualToString:@"Favorites"]) return @"Subreddits you've starred as a favorite";
    if ([kind isEqualToString:@"Multireddits"]) return @"Your saved multireddits";
    if ([kind isEqualToString:@"Moderator"]) return @"Subreddits you moderate";
    return nil;
}

@implementation ApolloHideSubredditSectionsViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Hide Subreddit Sections";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return ApolloHideSubredditSectionsKinds().count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Hides the whole section (header and its rows) from the Subreddits list -- not just individual items within it. Can be re-enabled here at any time.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *kind = ApolloHideSubredditSectionsKinds()[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    cell.textLabel.text = kind;
    cell.detailTextLabel.text = ApolloHideSubredditSectionsKindSubtitle(kind);

    UISwitch *toggle = [UISwitch new];
    NSArray<NSString *> *hidden = [[NSUserDefaults standardUserDefaults] stringArrayForKey:UDKeyHiddenSubredditIndexSections];
    toggle.on = [hidden containsObject:kind];
    toggle.tag = indexPath.row;
    [toggle addTarget:self action:@selector(apollo_toggled:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (void)apollo_toggled:(UISwitch *)sender {
    NSString *kind = ApolloHideSubredditSectionsKinds()[sender.tag];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *hidden = [([defaults stringArrayForKey:UDKeyHiddenSubredditIndexSections] ?: @[]) mutableCopy];
    if (sender.isOn) {
        if (![hidden containsObject:kind]) [hidden addObject:kind];
    } else {
        [hidden removeObject:kind];
    }
    [defaults setObject:hidden forKey:UDKeyHiddenSubredditIndexSections];
}

@end
