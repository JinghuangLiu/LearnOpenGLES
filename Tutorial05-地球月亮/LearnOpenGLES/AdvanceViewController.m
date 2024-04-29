//
//  AdvanceViewController.m
//  LearnOpenGLES
//
//  Created by loyinglin on 16/3/25.
//  Copyright © 2016年 loyinglin. All rights reserved.
//

#import "AdvanceViewController.h"
#import "AGLKVertexAttribArrayBuffer.h"
#import "sphere.h"

@interface AdvanceViewController ()

@property (nonatomic , strong) EAGLContext* mContext;

//缓存
@property (strong, nonatomic) AGLKVertexAttribArrayBuffer *vertexPositionBuffer;
@property (strong, nonatomic) AGLKVertexAttribArrayBuffer *vertexNormalBuffer;
@property (strong, nonatomic) AGLKVertexAttribArrayBuffer *vertexTextureCoordBuffer;

//效果
@property (strong, nonatomic) GLKBaseEffect *baseEffect;

//纹理
@property (strong, nonatomic) GLKTextureInfo *earthTextureInfo;
@property (strong, nonatomic) GLKTextureInfo *moonTextureInfo;

//模型视图矩阵
@property (nonatomic) GLKMatrixStackRef modelviewMatrixStack;

//地球旋转角度
@property (nonatomic) GLfloat earthRotationAngleDegrees;

//月球旋转角度
@property (nonatomic) GLfloat moonRotationAngleDegrees;

//切换投影：正交投影和透视投影
- (IBAction)takeShouldUsePerspectiveFrom:(UISwitch *)aControl;

@end

@implementation AdvanceViewController
{
}

//地球倾斜角度
static const GLfloat  SceneEarthAxialTiltDeg = 23.5f;
//月球绕地球一周的周期
static const GLfloat  SceneDaysPerMoonOrbit = 3.0f;
//static const GLfloat  SceneDaysPerMoonOrbit = 28.0f;
//月球的缩放
static const GLfloat  SceneMoonRadiusFractionOfEarth = 0.25;
//地球和月球的距离
static const GLfloat  SceneMoonDistanceFromEarth = 2.0;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    //新建OpenGLES 上下文
    self.mContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    GLKView* view = (GLKView *)self.view;
    view.context = self.mContext;
    view.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [EAGLContext setCurrentContext:self.mContext];
    
    glEnable(GL_DEPTH_TEST);
    
    self.baseEffect = [[GLKBaseEffect alloc] init];
    
    [self configureLight];
    
    //默认正交投影
    GLfloat aspectRatio = (self.view.bounds.size.width) / (self.view.bounds.size.height);
    self.baseEffect.transform.projectionMatrix = GLKMatrix4MakeOrtho(
                        -1.0 * aspectRatio,
                        1.0 * aspectRatio,
                        -1.0,
                        1.0,
                        1.0,
                        120.0);
    
//    self.baseEffect.transform.modelviewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -5.0);
    self.baseEffect.transform.modelviewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0);
    
    //顶点数组
    [self bufferData];
}

//太阳光
- (void)configureLight
{
    self.baseEffect.light0.enabled = GL_TRUE;
    //
    self.baseEffect.light0.diffuseColor = GLKVector4Make(
                                                         1.0f, // Red
                                                         1.0f, // Green
                                                         1.0f, // Blue
                                                         1.0f);// Alpha
    self.baseEffect.light0.position = GLKVector4Make(
                                                     1.0f,  
                                                     0.0f,  
                                                     0.8f,  
                                                     0.0f);
    self.baseEffect.light0.ambientColor = GLKVector4Make(
                                                         0.2f, // Red 
                                                         0.2f, // Green 
                                                         0.2f, // Blue 
                                                         1.0f);// Alpha 
}

- (void)bufferData {
    
    //默认模型视图矩阵
    self.modelviewMatrixStack = GLKMatrixStackCreate(kCFAllocatorDefault);
    
    //顶点数据缓存
    self.vertexPositionBuffer = [[AGLKVertexAttribArrayBuffer alloc]
                                 initWithAttribStride:(3 * sizeof(GLfloat))
                                 numberOfVertices:sizeof(sphereVerts) / (3 * sizeof(GLfloat))
                                 bytes:sphereVerts
                                 usage:GL_STATIC_DRAW];
    //法线数据缓存
    self.vertexNormalBuffer = [[AGLKVertexAttribArrayBuffer alloc]
                               initWithAttribStride:(3 * sizeof(GLfloat))
                               numberOfVertices:sizeof(sphereNormals) / (3 * sizeof(GLfloat))
                               bytes:sphereNormals
                               usage:GL_STATIC_DRAW];
    //纹理坐标数据缓存
    self.vertexTextureCoordBuffer = [[AGLKVertexAttribArrayBuffer alloc]
                                     initWithAttribStride:(2 * sizeof(GLfloat))
                                     numberOfVertices:sizeof(sphereTexCoords) / (2 * sizeof(GLfloat))
                                     bytes:sphereTexCoords
                                     usage:GL_STATIC_DRAW];
    
    //地球纹理
    CGImageRef earthImageRef = [[UIImage imageNamed:@"Earth512x256.jpg"] CGImage];
    self.earthTextureInfo = [GLKTextureLoader
                        textureWithCGImage:earthImageRef
                        options:[NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES],
                                 GLKTextureLoaderOriginBottomLeft, nil]
                        error:NULL];
    
    //月球纹理
    CGImageRef moonImageRef = [[UIImage imageNamed:@"Moon256x128.png"] CGImage];
    self.moonTextureInfo = [GLKTextureLoader
                       textureWithCGImage:moonImageRef
                       options:[NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:YES],
                                GLKTextureLoaderOriginBottomLeft, nil]
                       error:NULL];
    
    //矩阵赋值
    GLKMatrixStackLoadMatrix4(self.modelviewMatrixStack,
                              self.baseEffect.transform.modelviewMatrix);
    
    // Initialize Moon position in orbit
    self.moonRotationAngleDegrees = -20.0f;

}

//地球
- (void)drawEarth
{
    self.baseEffect.texture2d0.name = self.earthTextureInfo.name;
    self.baseEffect.texture2d0.target = self.earthTextureInfo.target;
    
    /*
     current matrix:
     1.000000 0.000000 0.000000 0.000000
     0.000000 1.000000 0.000000 0.000000
     0.000000 0.000000 1.000000 0.000000
     0.000000 0.000000 -5.000000 1.000000
     */
    GLKMatrixStackPush(self.modelviewMatrixStack);
    
    //倾斜旋转：SceneEarthAxialTiltDeg是固定值
    GLKMatrixStackRotate(
                         self.modelviewMatrixStack,
                         GLKMathDegreesToRadians(SceneEarthAxialTiltDeg),
                         1.0, 0.0, 0.0);
    /*
     current matrix:
     1.000000 0.000000 0.000000 0.000000
     0.000000 0.917060 0.398749 0.000000
     0.000000 -0.398749 0.917060 0.000000
     0.000000 0.000000 -5.000000 1.000000
     */
    
    //自转：earthRotationAngleDegrees是变化的值
    GLKMatrixStackRotate(
                         self.modelviewMatrixStack,
                         GLKMathDegreesToRadians(self.earthRotationAngleDegrees),
                         0.0, 1.0, 0.0);
    /*
     current matrix:
     0.994522 0.041681 -0.095859 0.000000
     0.000000 0.917060 0.398749 0.000000
     0.104528 -0.396565 0.912036 0.000000
     0.000000 0.000000 -5.000000 1.000000
     */
    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(self.modelviewMatrixStack);
    
    [self.baseEffect prepareToDraw];
    
    [AGLKVertexAttribArrayBuffer
     drawPreparedArraysWithMode:GL_TRIANGLES
     startVertexIndex:0
     numberOfVertices:sphereNumVerts];
    
    /*
     
     current matrix:
     0.994522 0.041681 -0.095859 0.000000
     0.000000 0.917060 0.398749 0.000000
     0.104528 -0.396565 0.912036 0.000000
     0.000000 0.000000 -5.000000 1.000000
     */
    GLKMatrixStackPop(self.modelviewMatrixStack);
    
    /*
     current matrix:
     1.000000 0.000000 0.000000 0.000000
     0.000000 1.000000 0.000000 0.000000
     0.000000 0.000000 1.000000 0.000000
     0.000000 0.000000 -5.000000 1.000000
    */
//    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(self.modelviewMatrixStack);
}


- (void)drawMoon
{
    self.baseEffect.texture2d0.name = self.moonTextureInfo.name;
    self.baseEffect.texture2d0.target = self.moonTextureInfo.target;
    
    //加载矩阵
    GLKMatrixStackPush(self.modelviewMatrixStack);
    
    //公转
//    GLKMatrixStackRotate(self.modelviewMatrixStack,
//                         GLKMathDegreesToRadians(self.moonRotationAngleDegrees),
//                         0.0, 1.0, 0.0);
    
    //地月距离
    GLKMatrixStackTranslate(self.modelviewMatrixStack,
                            0.0, 0.0, SceneMoonDistanceFromEarth);
    
    //月球的缩放
//    GLKMatrixStackScale(self.modelviewMatrixStack,
//                        SceneMoonRadiusFractionOfEarth,
//                        SceneMoonRadiusFractionOfEarth,
//                        SceneMoonRadiusFractionOfEarth);
    
    //自转
    GLKMatrixStackRotate(self.modelviewMatrixStack,
                         GLKMathDegreesToRadians(self.moonRotationAngleDegrees),
                         0.0, 1.0, 0.0);
    
    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(self.modelviewMatrixStack);
    
    [self.baseEffect prepareToDraw];
    
    [AGLKVertexAttribArrayBuffer
     drawPreparedArraysWithMode:GL_TRIANGLES
     startVertexIndex:0
     numberOfVertices:sphereNumVerts];
    
    GLKMatrixStackPop(self.modelviewMatrixStack);
    
//    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(self.modelviewMatrixStack);
}

- (IBAction)takeShouldUsePerspectiveFrom:(UISwitch *)aControl;
{
    GLfloat   aspectRatio =
    (float)((GLKView *)self.view).drawableWidth /
    (float)((GLKView *)self.view).drawableHeight;
    
    if([aControl isOn])
    {
        //使用透视投影
        self.baseEffect.transform.projectionMatrix =
        GLKMatrix4MakeFrustum(
                              -1.0 * aspectRatio,
                              1.0 * aspectRatio,
                              -1.0,
                              1.0,
                              2.0,
                              120.0);
//        self.baseEffect.transform.projectionMatrix =
//        GLKMatrix4MakePerspective(1.0, aspectRatio, 1.0, 50.0);
    }
    else
    {
        //使用正交投影
        self.baseEffect.transform.projectionMatrix =
        GLKMatrix4MakeOrtho(
                            -1.0 * aspectRatio,
                            1.0 * aspectRatio, 
                            -1.0, 
                            1.0, 
                            1.0,
                            120.0);  
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation !=
            UIInterfaceOrientationPortraitUpsideDown &&
            interfaceOrientation !=
            UIInterfaceOrientationPortrait);
}

/**
 *  渲染场景代码
 */
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    
    glClearColor(112/255.0f, 182/255.0f, 238/255.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    //2秒旋转360度
    self.earthRotationAngleDegrees += 360.0f / 60.0f;
    //2秒旋转360度/除以28天
    self.moonRotationAngleDegrees += (360.0f / 60.0f) / SceneDaysPerMoonOrbit;
    
    [self.vertexPositionBuffer
     prepareToDrawWithAttrib:GLKVertexAttribPosition
     numberOfCoordinates:3
     attribOffset:0
     shouldEnable:YES];
    [self.vertexNormalBuffer
     prepareToDrawWithAttrib:GLKVertexAttribNormal
     numberOfCoordinates:3
     attribOffset:0
     shouldEnable:YES];
    [self.vertexTextureCoordBuffer
     prepareToDrawWithAttrib:GLKVertexAttribTexCoord0
     numberOfCoordinates:2
     attribOffset:0
     shouldEnable:YES];
    
//    [self drawEarth];
    [self drawMoon];
}


@end
