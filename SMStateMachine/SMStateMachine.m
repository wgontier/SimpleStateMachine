
#import "SMStateMachine.h"
#import "SMCompositeAction.h"

@interface SMStateMachine ()
@property(strong, nonatomic, readonly) NSMutableArray *states;
@end

@implementation SMStateMachine
@synthesize states = _states;
@synthesize curState = _curState;
@synthesize globalExecuteIn = _globalExecuteIn;
@synthesize initialState = _initialState;
@synthesize monitor = _monitor;


- (SMState *)createState:(NSString *)name {
    SMState *state = [[SMState alloc] initWithName:name];
    [self.states addObject:state];
    return state;
}

- (SMDecision *)createDecision:(NSString *)name withPredicateBlock:(SMDecisionBlock)block {
    SMDecision* node = [[SMDecision alloc] initWithName:name andBlock:block];
    [self.states addObject:node];
    return node;
}

- (SMDecision *)createDecision:(NSString *)name withPredicateBoolBlock:(SMBoolDecisionBlock)block {
    SMDecision* node = [[SMDecision alloc] initWithName:name andBoolBlock:block];
    [self.states addObject:node];
    return node;
}

- (void)transitionFrom:(SMNode *)fromState to:(SMNode *)toState forEvent:(NSString *)event {
    [self transitionFrom:fromState to:toState forEvent:event withAction:nil];
}

- (void)transitionFrom:(SMNode *)fromState to:(SMNode *)toState forEvent:(NSString *)event withSel:(SEL)actionSel {
    [self transitionFrom:fromState to:toState forEvent:event withAction:[SMAction actionWithSel:actionSel]];
}

- (void)transitionFrom:(SMNode *)fromState to:(SMNode *)toState forEvent:(NSString *)event withSelectors:(SEL)firstSelector,... {
    va_list args;
    va_start(args, firstSelector);
    [self transitionFrom:fromState to:toState forEvent:event withAction:[SMCompositeAction actionWithFirstSelector:firstSelector andVaList:args]];
    va_end(args);
}

- (void)transitionFrom:(SMNode *)fromState to:(SMNode *)toState forEvent:(NSString *)event withSel:(SEL)actionSel executeIn:(NSObject *)executeIn {
    [self transitionFrom:fromState to:toState forEvent:event withAction:[SMAction actionWithSel:actionSel executeIn:executeIn]];
}

- (void)trueTransitionFrom:(SMDecision *)fromState to:(SMNode *)toState {
    [self transitionFrom:fromState to:toState forEvent:SM_EVENT_TRUE withAction:nil];
}

- (void)trueTransitionFrom:(SMDecision *)fromState to:(SMNode *)toState withSel:(SEL)actionSel {
    [self transitionFrom:fromState to:toState forEvent:SM_EVENT_TRUE withAction:[SMAction actionWithSel:actionSel]];
}

- (void)falseTransitionFrom:(SMDecision *)fromState to:(SMNode *)toState {
    [self transitionFrom:fromState to:toState forEvent:SM_EVENT_FALSE withAction:nil];
}

- (void)falseTransitionFrom:(SMDecision *)fromState to:(SMNode *)toState withSel:(SEL)actionSel {
    [self transitionFrom:fromState to:toState forEvent:SM_EVENT_FALSE withAction:[SMAction actionWithSel:actionSel]];
}

- (void)internalTransitionFrom:(SMNode *)fromState forEvent:(NSString *)event withSel:(SEL)actionSel {
    [self transitionFrom:fromState to:nil forEvent:event withAction:[SMAction actionWithSel:actionSel]];
}

- (void)internalTransitionFrom:(SMNode *)fromState forEvent:(NSString *)event withSelectors:(SEL)firstSelector, ... {
    va_list args;
    va_start(args, firstSelector);
    [self transitionFrom:fromState to:nil forEvent:event withAction:[SMCompositeAction actionWithFirstSelector:firstSelector andVaList:args]];
    va_end(args);
}

- (void)internalTransitionFrom:(SMNode *)fromState forEvent:(NSString *)event withSel:(SEL)actionSel executeIn:(NSObject *)executeIn {
    [self transitionFrom:fromState to:nil forEvent:event withAction:[SMAction actionWithSel:actionSel executeIn:executeIn]];
}

- (void)transitionFrom:(SMNode *)fromState to:(SMNode *)toState forEvent:(NSString *)event withAction:(id<SMActionProtocol>)action {
    SMTransition *transition = [[SMTransition alloc] init];
    transition.from = fromState;
    transition.to = toState;
    transition.event = event;
    transition.action = action;
    [fromState _addTransition:transition];
}

- (void)validate {
    if ([self.states count] == 0) {
        [NSException raise:@"Invalid statemachine" format:@"No states"];
    }
    if (_initialState == nil) {
        [NSException raise:@"Invalid statemachine" format:@"initialState is nil"];
    }
    //TODO: Add more validations
}


- (void)post:(NSString *)event {
    SMStateMachineExecuteContext *context = [[SMStateMachineExecuteContext alloc] init];
    context.globalExecuteIn = self.globalExecuteIn;
    context.monitor = self.monitor;
    context.curState = _curState;
    [_curState _postEvent:event withContext:context];
    _curState = context.curState;
}



- (NSMutableArray *)states {
    if (_states == nil) {
        _states = [[NSMutableArray alloc] init];
    }
    return _states;
}



-(void)setInitialState:(SMState*)aState {
    _initialState = aState;
    if (_curState == nil) {
        _curState = _initialState;
    }
}



-(void)reset
{
    _curState = _initialState;
}



//
// Add-ons : Load FSM from Dictionary / JSON Data
// William Gontier - Nov 2018
//
// Idea behind : https://gojs.net/latest/samples/stateChart.html
//
#define fieldForStatesArray @"nodeDataArray"
#define fieldForStateId @"text"
#define fieldForStateEntrySelectorId @"actionIn"
#define fieldForStateExitSelectorId @"actionOut"

#define fieldForLinksArray @"linkDataArray"
#define fieldForLinkFromId @"from"
#define fieldForLinkToId @"to"
#define fieldForLinkEventId @"text"
#define fieldForLinkSelectorId @"action"

/**
 Load FSM from a description stored in a disctionary
 
 @param description Dictionary containing the FSM description
 @return TRUE : OK, FALSE : KO
 */
-(BOOL)loadFromDescription:(NSDictionary *) description
{
    NSArray *statesDescription = description[fieldForStatesArray];
    
    for (NSDictionary *stateDescription in statesDescription)
    {
        if(stateDescription[fieldForStateId] == nil)
        {
            return(FALSE);
        }
        
        SMState *state = [[SMState alloc] initWithName:stateDescription[fieldForStateId]];
        if (state != nil)
        {
            if (stateDescription[fieldForStateEntrySelectorId] != nil)
            {
                SEL selector = NSSelectorFromString(stateDescription[fieldForStateEntrySelectorId]);
                if ([self respondsToSelector:selector])
                {
                    [state setEntrySelector:selector];
                }
                else return(FALSE);
            }
            if (stateDescription[fieldForStateExitSelectorId] != nil)
            {
                SEL selector = NSSelectorFromString(stateDescription[fieldForStateExitSelectorId]);
                if ([self respondsToSelector:selector])
                {
                    [state setExitSelector:selector];
                }
                else return(FALSE);
            }
            else return(FALSE);
        }
        else return(FALSE);
    }
    
    NSArray *linksDescription = description[fieldForStatesArray];

    for (NSDictionary *linkDescription in linksDescription)
    {
        if(linkDescription[fieldForLinkFromId] == nil ||
           linkDescription[fieldForLinkToId] == nil ||
           linkDescription[fieldForLinkEventId] == nil)
        {
            return(FALSE);
        }
        
        if (linkDescription[fieldForLinkSelectorId] != nil)
        {
            SEL selector = NSSelectorFromString(linkDescription[fieldForLinkSelectorId]);
            if ([self respondsToSelector:selector])
            {
                [self transitionFrom:linkDescription[fieldForLinkFromId] to:linkDescription[fieldForLinkToId] forEvent:linkDescription[fieldForLinkEventId] withSel:selector];
            }
            else return(FALSE);
        }
        else
        {
            [self transitionFrom:linkDescription[fieldForLinkFromId] to:linkDescription[fieldForLinkToId] forEvent:linkDescription[fieldForLinkEventId]];
        }
    }
    
    return(TRUE);
}



/**
 loadFromJSON

 @param data JSON data containing the FSM description
 @return TRUE : OK, FALSE : KO
 */
-(BOOL)loadFromJSON:(NSData*) data
{
    NSError *error;
    
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    if (error != nil) return(FALSE);
    
    if ( ! [self loadFromDescription:dictionary]) return(FALSE);
    
    return(TRUE);
}

@end






