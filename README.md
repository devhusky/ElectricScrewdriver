![title_image.png](https://upload-images.jianshu.io/upload_images/9487547-307a9d5bbbb2e523.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/800)

开发过程中总是会遇到一些繁琐且枯燥的机械式代码（俗称：拧螺丝）。比如在布局时声明完控件属性，需要一个个属性的去生成懒加载方法，并在懒加载中设置控件的属性；比如接口返回JSON数据，需要先将JSON转成Model对象，就需要根据JSON中的字段，一个个声明成对应的属性。那有什么办法可以更加快捷完成这些拧螺丝的部分吗？答案是肯定的，用电动螺丝刀就好了。本文将提供"电动螺丝刀"插件，高效完成懒加载生成与JSON转Model。
## 
一、快速声明属性
属性结构如下，每次声明一个属性，每次都需要重复输入声明、修饰符、类型和变量名。其实除了类型和变量名，其他结构基本一致，这种情况其实完全可以将重复的部分生成代码块，这样就可以通过极短的输入提示出完整的属性声明。
![1.gif](https://upload-images.jianshu.io/upload_images/9487547-5f2b52708187cea6.gif?imageMogr2/auto-orient/strip)
常规输入，虽然IDE也会有自动提示，不过还是不够快。
![2.gif](https://upload-images.jianshu.io/upload_images/9487547-b6c5bcaaa179ab82.gif?imageMogr2/auto-orient/strip)

代码块输入，只需要输入代码块对应的关键字，就会直接提示整个代码块。直接tab选中占位符即可直接输入类型和变量名。

## 二、代码块创建

1. 选中代码块，右键，再选择项中点击Create Code Snippet。

![image.png](https://upload-images.jianshu.io/upload_images/9487547-66397f1e489ca18e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/800)

2. 输入代码块名称和关键字（根据个人喜好编辑即可）。编辑代码块，将类型和变量名修改为占位形式，这样可以直接tab选中占位并直接输入。

![image.png](https://upload-images.jianshu.io/upload_images/9487547-993493947e535f89.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/800)


3. 测试。输入pstrong，即可提示出刚刚创建的代码块了。

![image.png](https://upload-images.jianshu.io/upload_images/9487547-88278e67208a7627.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/800)


## 三、批量生成懒加载
点击工具栏 Editor -> ESExtension -> Generator Property Getter 或快捷键 ^ + G 生成属性懒加载。
效果：
![3.gif](https://upload-images.jianshu.io/upload_images/9487547-7fc90a6abba4959b.gif?imageMogr2/auto-orient/strip)

## 四、JSON转OC Model
效果：
![4.gif](https://upload-images.jianshu.io/upload_images/9487547-48a935b4d6410863.gif?imageMogr2/auto-orient/strip)

示例

1. 将如下JSON复制到Xcode中，点击工具栏 Editor -> ESExtension -> JSON To OC Model
```json
{
    "name":"Xiao Wang",
    "email":"xiaowang@example.com",
    "father":{
        "name":"Lao Wang",
        "email":"laowang@example.com"
    },
    "friends":[
        {
            "name":"Zhang San",
            "email":"zhangsan@example.com"
        },
        {
            "name":"Li Si",
            "email":"lisi@example.com"
        }
    ]
}
```

2. 此时会在直接将以上JSON转成如下Model。
```objectivec
@class  HMFriendsModel; 
@class  HMFatherModel; 
@interface  XiaoWang : NSObject 
@property  (nonatomic, copy) NSString *name; 
@property  (nonatomic, strong) NSArray<HMFriendsModel > friends;
@property  (nonatomic, strong) HMFatherModel *father; 
@property  (nonatomic, copy) NSString *email; 
@end  

@interface  HMFriendsModel : NSObject 
@property  (nonatomic, copy) NSString *name; 
@property  (nonatomic, copy) NSString *email; 
@end  

@interface  HMFatherModel : NSObject 
@property  (nonatomic, copy) NSString *email; 
@property  (nonatomic, copy) NSString *name; 
@end  

@implementation  XiaoWang 

- (NSDictionary *)modelContainerPropertyGenericClass {
    return @{
        @"friends" : [HMFriendsModel class]
    };
}

@end  

@implementation  HMFriendsModel 
@end  

@implementation  HMFatherModel 
@end  
```

3. 以上JSON转Model乍一看貌似感觉挺好。直接就全部生成了，并且引用关系也建立了，但是仔细一想，这貌似不是想要的效果。这里边的Model，不管是xiaowang还是laowang都应该是同一个Person对象才是。所以我们期望生成的Model应该是下面这样的：
```objectivec
@interface  HMPersonModel : NSObject 
@property  (nonatomic, strong) NSArray<HMPersonModel > friends;
@property  (nonatomic, strong) HMPersonModel *father; 
@property  (nonatomic, copy) NSString *email; 
@property  (nonatomic, copy) NSString *name; 
@end  

@implementation  HMPersonModel 

- (NSDictionary *)modelContainerPropertyGenericClass {
	return @{
    	@"friends" : [HMPersonModel class]
    };
}

@end  
```

这时，我们只需要在转成Model之前简单修改一下JSON，添加一些特殊标志。
```json
{
  "$class":"HMPersonModel",
  "name":"Xiao Wang",
  "email":"xiaowang@example.com",
  "father":"$HMPersonModel",
  "friends":"$[]HMPersonModel"
}
```
> 说明："$prefix"自定义前缀，默认前缀"HM"；"$class"用来自定义当前类名；可以通过"$<自定义类名>"来自定义属性对象类名，或通过"$[]<自定义类名>"自定义数组对象类名。如以上示例的"$HMPersonModel"和"$[]HMPersonModel"。
> 由于Xcode Extension只能获取和编辑当前文件的内容，所以如果是在.h文件中JSON转Model，需要将生成的@implementation部分手动拷贝到.m文件中。


## 五、插件
插件下载：
https://github.com/devhusky/ElectricScrewdriver

插件设置，授权扩展权限
![扩展设置_1.png](https://upload-images.jianshu.io/upload_images/9487547-ae5f9166faadb5ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/800)

![扩展开启_2.png](https://upload-images.jianshu.io/upload_images/9487547-b9cfce641e78fdc7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/800)

![扩展开启_3.png](https://upload-images.jianshu.io/upload_images/9487547-9e97025d54ce4c13.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/800)

设置快捷键
点击工具栏 Xcode -> Perferences -> Key Bindings -> 搜索 ESExtension -> 点击key输入框编辑快捷键
![image.png](https://upload-images.jianshu.io/upload_images/9487547-2bc350030ca72e8b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/800)

Tips: 如果Key Bindings 无法编辑，切换到系统英文输入法，再进行编辑。
